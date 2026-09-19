# SPDX-FileCopyrightText: 2022 ash_paper_trail contributors <https://github.com/ash-project/ash_paper_trail/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshPaperTrail.Resource.Changes.CreateNewVersion do
  @moduledoc "Creates a new version whenever a resource is created, deleted, or updated"
  use Ash.Resource.Change

  @impl true
  def temporal_safe?(_opts), do: true

  @impl true
  def change(changeset, _, _) do
    cond do
      AshPaperTrail.Resource.Info.temporal_inline?(changeset.resource) ->
        stamp_inline_version(changeset, :force_change)

      valid_for_tracking?(changeset) ->
        create_new_version(changeset)

      true ->
        changeset
    end
  end

  @impl true
  def atomic(changeset, _opts, _context) do
    change_tracking_mode = AshPaperTrail.Resource.Info.change_tracking_mode(changeset.resource)

    cond do
      change_tracking_mode == :full_diff ->
        {:not_atomic,
         "Cannot perform full_diff change tracking with AshPaperTrail atomically. " <>
           "You might want to choose a different tracking mode or set require_atomic? to false on your update actions."}

      AshPaperTrail.Resource.Info.temporal_inline?(changeset.resource) ->
        # A fully atomic changeset cannot carry `before_action` hooks. Our change runs
        # last, so every other change's atomics are already on the changeset and we can
        # stamp it directly.
        {:ok, stamp_inline_version(changeset, :atomic)}

      change_tracking_mode == :previous_values ->
        {:not_atomic,
         "Cannot perform previous_values change tracking with AshPaperTrail atomically outside of `mode :temporal_inline`. " <>
           "You might want to choose a different tracking mode or set require_atomic? to false on your update actions."}

      true ->
        # Changes will be tracked in after_batch
        {:ok, changeset}
    end
  end

  @impl true
  def batch_change(changesets, _opts, _context) do
    case changesets do
      [%{resource: resource} | _] ->
        if AshPaperTrail.Resource.Info.temporal_inline?(resource) do
          Enum.map(changesets, &stamp_inline_version(&1, :force_change))
        else
          changesets
        end

      _ ->
        changesets
    end
  end

  @impl true
  def after_batch([], _, _), do: []

  def after_batch([{changeset, _} | _] = changesets_and_results, _opts, _context) do
    if valid_for_tracking?(changeset) and
         not AshPaperTrail.Resource.Info.temporal_inline?(changeset.resource) do
      inputs = bulk_build_notifications(changesets_and_results)

      if Enum.any?(inputs) do
        version_resource = AshPaperTrail.Resource.Info.version_resource(changeset.resource)
        version_changeset = Ash.Changeset.new(version_resource)
        actor = get_in(changeset.context, [:private, :actor])
        bulk_create!(changeset, version_changeset, inputs, actor)
      end
    end

    Enum.map(changesets_and_results, fn {_, result} -> {:ok, result} end)
  end

  defp stamp_inline_version(%Ash.Changeset{action_type: :destroy} = changeset, _strategy),
    do: changeset

  defp stamp_inline_version(changeset, strategy) do
    resource = changeset.resource
    stamp_attributes = AshPaperTrail.Resource.Info.temporal_inline_attributes(resource)

    other_changes? =
      changeset.attributes |> Map.drop(stamp_attributes) |> Enum.any?() ||
        changeset.atomics |> Keyword.drop(stamp_attributes) |> Enum.any?()

    cond do
      changeset.action_type == :update && !other_changes? &&
          skip_when_unchanged?(changeset) ->
        changeset

      !valid_for_tracking?(changeset) ->
        # The new row copies the previous version's stamp, which would describe a write
        # other than this one. Clear it rather than leave it misleading.
        if changeset.action_type == :update && other_changes? do
          clear_inline_version(changeset, stamp_attributes, strategy)
        else
          changeset
        end

      true ->
        changeset
        |> put_inline_version(strategy)
        |> put_inline_changes(stamp_attributes, strategy)
        |> include_in_upsert_fields(stamp_attributes)
    end
  end

  defp put_value(changeset, attribute, value, :force_change),
    do: Ash.Changeset.force_change_attribute(changeset, attribute, value)

  defp put_value(changeset, attribute, value, :atomic),
    do: Ash.Changeset.atomic_update(changeset, attribute, value)

  defp skip_when_unchanged?(changeset) do
    AshPaperTrail.Resource.Info.only_when_changed?(changeset.resource) ||
      changeset.context[:skip_version_when_unchanged?] == true
  end

  defp clear_inline_version(changeset, stamp_attributes, strategy) do
    Enum.reduce(stamp_attributes, changeset, fn name, changeset ->
      case Ash.Resource.Info.attribute(changeset.resource, name) do
        %{allow_nil?: true} -> put_value(changeset, name, nil, strategy)
        _ -> changeset
      end
    end)
  end

  defp put_inline_version(changeset, strategy) do
    resource = changeset.resource
    actor = get_in(changeset.context, [:private, :actor])
    sensitive_mode = sensitive_mode(changeset)
    paper_trail_metadata = changeset.context[:paper_trail_metadata] || %{}

    changeset
    |> put_value(:version_action_type, changeset.action.type, strategy)
    |> then(fn changeset ->
      if AshPaperTrail.Resource.Info.store_action_name?(resource) do
        put_value(changeset, :version_action_name, changeset.action.name, strategy)
      else
        changeset
      end
    end)
    |> then(fn changeset ->
      if AshPaperTrail.Resource.Info.store_action_inputs?(resource) do
        put_value(
          changeset,
          :version_action_inputs,
          action_inputs(changeset, sensitive_mode),
          strategy
        )
      else
        changeset
      end
    end)
    |> then(fn changeset ->
      resource
      |> AshPaperTrail.Resource.Info.belongs_to_actor()
      |> Enum.reduce(changeset, fn belongs_to_actor, changeset ->
        source_attribute =
          AshPaperTrail.Resource.Info.actor_source_attribute(resource, belongs_to_actor)

        value =
          if is_struct(actor) && actor.__struct__ == belongs_to_actor.destination do
            Map.get(actor, hd(Ash.Resource.Info.primary_key(actor.__struct__)))
          end

        put_value(changeset, source_attribute, value, strategy)
      end)
    end)
    |> then(fn changeset ->
      resource
      |> AshPaperTrail.Resource.Info.metadata()
      |> Enum.reduce(changeset, fn meta, changeset ->
        put_value(changeset, meta.name, Map.get(paper_trail_metadata, meta.name), strategy)
      end)
    end)
  end

  defp put_inline_changes(changeset, stamp_attributes, strategy) do
    resource = changeset.resource
    change_tracking_mode = AshPaperTrail.Resource.Info.change_tracking_mode(resource)

    if change_tracking_mode == :snapshot do
      # The period row *is* the snapshot.
      changeset
    else
      sensitive_mode = sensitive_mode(changeset)

      resource_attributes =
        resource
        |> Ash.Resource.Info.attributes()
        |> Map.new(&{&1.name, &1})

      to_skip =
        Ash.Resource.Info.primary_key(resource) ++
          AshPaperTrail.Resource.Info.ignore_attributes(resource) ++
          stamp_attributes ++ List.wrap(Ash.Resource.Info.temporal_attribute(resource))

      tracked = resource_attributes |> Map.drop(to_skip) |> Map.values()

      atomics = Keyword.drop(changeset.atomics, stamp_attributes)

      if change_tracking_mode in [:changes_only, :previous_values] &&
           (atomics != [] || strategy == :atomic) do
        changes =
          tracked
          |> Enum.reduce(%{}, fn attribute, changes ->
            cond do
              change_tracking_mode == :previous_values &&
                  (Keyword.has_key?(atomics, attribute.name) ||
                     Ash.Changeset.changing_attribute?(changeset, attribute.name)) ->
                Map.put(changes, attribute.name, Ash.Expr.ref(attribute.name))

              change_tracking_mode == :previous_values ->
                changes

              Keyword.has_key?(atomics, attribute.name) ->
                Map.put(changes, attribute.name, atomics[attribute.name])

              Ash.Changeset.changing_attribute?(changeset, attribute.name) ->
                AshPaperTrail.ChangeBuilders.ChangesOnly.build_attribute_change(
                  attribute,
                  changeset,
                  sensitive_mode,
                  changeset.attributes,
                  changes
                )

              true ->
                changes
            end
          end)
          |> maybe_redact_changes(resource_attributes, sensitive_mode)

        Ash.Changeset.atomic_update(changeset, :changes, {:atomic, changes})
      else
        {:ok, projected} = Ash.Changeset.apply_attributes(changeset, force?: true)

        changes =
          tracked
          |> build_changes(change_tracking_mode, changeset, projected)
          |> maybe_redact_changes(resource_attributes, sensitive_mode)

        put_value(changeset, :changes, changes, strategy)
      end
    end
  end

  defp include_in_upsert_fields(changeset, stamp_attributes) do
    case changeset.context[:private] do
      %{upsert?: true, upsert_fields: upsert_fields} when is_list(upsert_fields) ->
        Ash.Changeset.set_context(changeset, %{
          private: %{upsert_fields: Enum.uniq(upsert_fields ++ stamp_attributes)}
        })

      _ ->
        changeset
    end
  end

  defp sensitive_mode(changeset) do
    changeset.context[:sensitive_attributes] ||
      AshPaperTrail.Resource.Info.sensitive_attributes(changeset.resource)
  end

  # --- :version_resource mode ------------------------------------------------------------

  defp valid_for_tracking?(%Ash.Changeset{} = changeset) do
    !changeset.context[:ash_paper_trail_disabled?] &&
      changeset.action.name not in AshPaperTrail.Resource.Info.ignore_actions(changeset.resource) &&
      (changeset.action_type == :create ||
         (changeset.action_type == :destroy &&
            AshPaperTrail.Resource.Info.create_version_on_destroy?(changeset.resource)) ||
         (changeset.action_type == :update &&
            changeset.action.name in AshPaperTrail.Resource.Info.on_actions(changeset.resource)))
  end

  defp create_new_version(changeset) do
    Ash.Changeset.after_action(changeset, fn changeset, result ->
      if !changeset.context[:ash_paper_trail_disabled?] do
        if valid_for_tracking?(changeset) do
          changed? = changed?(changeset, result)

          if should_record_version_for_action?(changeset, changed?) do
            {version_changeset, input, actor} = build_notifications(changeset, result)
            create!(changeset, version_changeset, input, actor)
          end
        end
      end

      {:ok, result}
    end)
  end

  defp should_record_version_for_action?(changeset, changed?) do
    case changeset.action_type do
      :create ->
        upsert? = get_in(changeset.context, [:private, :upsert?])
        !upsert? || (upsert? && changed?)

      :destroy ->
        AshPaperTrail.Resource.Info.create_version_on_destroy?(changeset.resource)

      :update ->
        changed?

      _ ->
        false
    end
  end

  defp bulk_build_notifications(changesets_and_results) do
    changesets_and_results
    |> Enum.filter(fn {changeset, result} ->
      changed? = changed?(changeset, result)
      should_record_version_for_action?(changeset, changed?)
    end)
    |> Enum.map(fn {changeset, result} -> build_notifications(changeset, result, bulk?: true) end)
    |> Enum.reduce([], fn input, inputs -> [input | inputs] end)
  end

  defp changed?(changeset, result) do
    cond do
      changeset.action_type == :update ->
        if AshPaperTrail.Resource.Info.only_when_changed?(changeset.resource) do
          changeset.context.changed?
        else
          !changeset.context[:skip_version_when_unchanged?] ||
            changeset.context.changed?
        end

      changeset.action_type == :create ->
        if AshPaperTrail.Resource.Info.only_when_changed?(changeset.resource) do
          !Ash.Resource.get_metadata(result, :upsert_skipped)
        else
          !changeset.context[:skip_version_when_unchanged?] ||
            !Ash.Resource.get_metadata(result, :upsert_skipped)
        end

      true ->
        true
    end
  end

  defp build_notifications(changeset, result, opts \\ []) do
    version_resource = AshPaperTrail.Resource.Info.version_resource(changeset.resource)

    version_resource_attributes =
      version_resource |> Ash.Resource.Info.attributes() |> Enum.map(& &1.name)

    to_skip =
      Ash.Resource.Info.primary_key(changeset.resource) ++
        AshPaperTrail.Resource.Info.ignore_attributes(changeset.resource)

    attributes_as_attributes =
      AshPaperTrail.Resource.Info.attributes_as_attributes(changeset.resource)

    change_tracking_mode = AshPaperTrail.Resource.Info.change_tracking_mode(changeset.resource)

    belongs_to_actors =
      AshPaperTrail.Resource.Info.belongs_to_actor(changeset.resource)

    actor = get_in(changeset.context, [:private, :actor])

    sensitive_mode =
      changeset.context[:sensitive_attributes] ||
        AshPaperTrail.Resource.Info.sensitive_attributes(changeset.resource)

    resource_attributes =
      changeset.resource
      |> Ash.Resource.Info.attributes()
      |> Map.new(&{&1.name, &1})

    input =
      version_resource_attributes
      |> Enum.filter(&(&1 in attributes_as_attributes))
      |> Enum.reject(&(resource_attributes[&1].sensitive? and sensitive_mode != :display))
      |> Map.new(&{&1, Map.get(result, &1)})

    changes =
      resource_attributes
      |> Map.drop(to_skip)
      |> Map.values()
      |> build_changes(change_tracking_mode, changeset, result)
      |> maybe_redact_changes(resource_attributes, sensitive_mode)

    action_inputs =
      if AshPaperTrail.Resource.Info.store_action_inputs?(changeset.resource) do
        action_inputs(changeset, sensitive_mode)
      else
        %{}
      end

    input =
      Enum.reduce(belongs_to_actors, input, fn belongs_to_actor, input ->
        with true <- is_struct(actor) && actor.__struct__ == belongs_to_actor.destination,
             relationship when not is_nil(relationship) <-
               Ash.Resource.Info.relationship(version_resource, belongs_to_actor.name) do
          primary_key = Map.get(actor, hd(Ash.Resource.Info.primary_key(actor.__struct__)))
          source_attribute = Map.get(relationship, :source_attribute)
          Map.put(input, source_attribute, primary_key)
        else
          _ ->
            input
        end
      end)
      |> Map.merge(
        AshPaperTrail.Resource.PrimaryKey.version_source_input(result, changeset.resource)
      )
      |> Map.merge(%{
        version_action_type: changeset.action.type,
        version_action_name: changeset.action.name,
        version_action_inputs: action_inputs,
        version_resource_identifier:
          AshPaperTrail.Resource.Info.resource_identifier(changeset.resource),
        changes: changes
      })

    metadata_entities = AshPaperTrail.Resource.Info.metadata(changeset.resource)
    paper_trail_metadata = changeset.context[:paper_trail_metadata] || %{}

    input =
      Enum.reduce(metadata_entities, input, fn meta, input ->
        Map.put(input, meta.name, Map.get(paper_trail_metadata, meta.name))
      end)

    if Keyword.get(opts, :bulk?) do
      input
    else
      {Ash.Changeset.new(version_resource), input, actor}
    end
  end

  defp action_inputs(changeset, sensitive_mode) do
    action_input_attrs =
      changeset.action.accept
      |> Enum.map(fn attr_name ->
        attr_info = Ash.Resource.Info.attribute(changeset.resource, attr_name)
        {present, params_value} = get_raw_params_value_if_present(changeset.params, attr_name)

        %{
          name: attr_name,
          type: :attribute,
          ash_type: attr_info.type,
          constraints: attr_info.constraints,
          present?: present,
          params_value: params_value,
          sensitive?: attr_info.sensitive?
        }
      end)

    action_input_args =
      changeset.action.arguments
      |> Enum.map(fn arg ->
        {present, params_value} = get_raw_params_value_if_present(changeset.params, arg.name)

        %{
          name: arg.name,
          type: :argument,
          ash_type: arg.type,
          constraints: arg.constraints,
          present?: present,
          params_value: params_value,
          sensitive?: arg.sensitive?
        }
      end)

    (action_input_attrs ++ action_input_args)
    |> Enum.reduce(%{}, fn input, action_inputs ->
      cond do
        not input.present? ->
          action_inputs

        input.sensitive? ->
          Map.put(action_inputs, input.name, "REDACTED")

        true ->
          input_value =
            case input.type do
              :attribute ->
                changeset.casted_attributes[input.name] || changeset.attributes[input.name]

              :argument ->
                changeset.casted_arguments[input.name] || changeset.arguments[input.name]
            end

          constraints =
            if Ash.Type.NewType.new_type?(input.ash_type) do
              Ash.Type.NewType.constraints(input.ash_type, input.constraints)
            else
              input.constraints
            end

          case Ash.Type.dump_to_embedded(input.ash_type, input_value, constraints) do
            {:ok, value} ->
              value =
                AshPaperTrail.ChangeBuilders.FullDiff.Helpers.redact_dumped_value(
                  value,
                  input.ash_type,
                  constraints,
                  sensitive_mode
                )

              casted_params_value = extract_casted_params_values(value, input.params_value)
              Map.put(action_inputs, input.name, casted_params_value)

            :error ->
              raise "Unable to serialize input value for #{input.name}"
          end
      end
    end)
  end

  defp get_raw_params_value_if_present(params, key) when is_atom(key) do
    key_as_string = Atom.to_string(key)

    present =
      Map.has_key?(params, key) ||
        Map.has_key?(params, key_as_string)

    if present do
      {true, Map.get(params, key) || Map.get(params, key_as_string)}
    else
      {false, nil}
    end
  end

  defp extract_casted_params_values(casted_value, params_value) do
    cond do
      is_map(casted_value) and is_map(params_value) and not is_struct(params_value) and
          not is_struct(casted_value) ->
        params_keys = Map.keys(params_value)

        Map.take(casted_value, params_keys)
        |> Enum.map(fn {key, value} ->
          {key, extract_casted_params_values(value, Map.get(params_value, key))}
        end)
        |> Enum.into(%{})

      is_list(casted_value) and is_list(params_value) ->
        Enum.zip(casted_value, params_value)
        |> Enum.map(fn {casted_value, params_value} ->
          extract_casted_params_values(casted_value, params_value)
        end)

      is_tuple(casted_value) and is_tuple(params_value) ->
        Enum.zip(Tuple.to_list(casted_value), Tuple.to_list(params_value))
        |> Enum.map(fn {casted_value, params_value} ->
          extract_casted_params_values(casted_value, params_value)
        end)
        |> List.to_tuple()

      true ->
        casted_value
    end
  end

  defp bulk_create!(changeset, version_changeset, inputs, actor) do
    opts = [
      context: version_context(changeset),
      authorize?: authorize?(changeset.domain),
      actor: actor,
      tenant: changeset.tenant,
      domain: changeset.domain,
      stop_on_error?: true,
      return_errors?: true,
      return_records?: true,
      skip_unknown_inputs: Enum.flat_map(inputs, &Map.keys(&1))
    ]

    inputs
    |> Ash.bulk_create!(version_changeset.resource, :create, opts)
    |> Map.get(:notifications)
  end

  defp create!(changeset, version_changeset, input, actor) do
    version_changeset
    |> Ash.Changeset.set_context(version_context(changeset))
    |> Ash.Changeset.for_create(:create, input,
      tenant: changeset.tenant,
      authorize?: authorize?(changeset.domain),
      actor: actor,
      domain: changeset.domain,
      skip_unknown_inputs: Map.keys(input)
    )
    |> Ash.create!()
  end

  defp build_changes(attributes, :changes_only, changeset, result) do
    AshPaperTrail.ChangeBuilders.ChangesOnly.build_changes(attributes, changeset, result)
  end

  defp build_changes(attributes, :snapshot, changeset, result) do
    AshPaperTrail.ChangeBuilders.Snapshot.build_changes(attributes, changeset, result)
  end

  defp build_changes(attributes, :full_diff, changeset, result) do
    AshPaperTrail.ChangeBuilders.FullDiff.build_changes(attributes, changeset, result)
  end

  defp build_changes(attributes, :previous_values, changeset, result) do
    AshPaperTrail.ChangeBuilders.PreviousValues.build_changes(attributes, changeset, result)
  end

  defp version_context(changeset) do
    %{ash_paper_trail?: true, shared: changeset.context[:shared] || %{}}
  end

  defp authorize?(domain), do: Ash.Domain.Info.authorize(domain) == :always

  defp maybe_redact_changes(changes, _, :display), do: changes

  defp maybe_redact_changes(changes, attributes, :redact) do
    attributes
    |> Map.values()
    |> Enum.filter(& &1.sensitive?)
    |> Enum.reduce(changes, fn attribute, changes ->
      Map.put(changes, attribute.name, "REDACTED")
    end)
  end

  defp maybe_redact_changes(changes, attributes, :ignore) do
    sensitive_attributes =
      attributes
      |> Map.values()
      |> Enum.filter(& &1.sensitive?)
      |> Enum.map(& &1.name)

    Map.drop(changes, sensitive_attributes)
  end
end
