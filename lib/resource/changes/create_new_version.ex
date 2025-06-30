defmodule AshPaperTrail.Resource.Changes.CreateNewVersion do
  @moduledoc "Creates a new version whenever a resource is created, deleted, or updated"
  use Ash.Resource.Change

  require Ash.Query
  require Logger

  @impl true
  def change(changeset, _, _) do
    if valid_for_tracking?(changeset) do
      create_new_version(changeset)
    else
      changeset
    end
  end

  @impl true
  def atomic(changeset, _opts, _context) do
    change_tracking_mode = AshPaperTrail.Resource.Info.change_tracking_mode(changeset.resource)

    if change_tracking_mode == :full_diff do
      {:not_atomic,
       "Cannot perform full_diff change tracking with AshPaperTrail atomically. " <>
         "You might want to choose a different tracking mode or set require_atomic? to false on your update actions."}
    else
      # Changes will be tracked in after_batch
      {:ok, changeset}
    end
  end

  @impl true
  def batch_change(changesets, _opts, _context) do
    changesets
  end

  @impl true
  def after_batch([], _, _), do: []

  def after_batch([{changeset, _} | _] = changesets_and_results, _opts, _context) do
    if valid_for_tracking?(changeset) do
      inputs = bulk_build_notifications(changesets_and_results)

      if Enum.any?(inputs) do
        version_resource = AshPaperTrail.Resource.Info.version_resource(changeset.resource)
        version_changeset = Ash.Changeset.new(version_resource)
        actor = changeset.context[:private][:actor]
        bulk_create!(changeset, version_changeset, inputs, actor)
      end
    end

    Enum.map(changesets_and_results, fn {_, result} -> {:ok, result} end)
  end

  defp valid_for_tracking?(%Ash.Changeset{} = changeset) do
    changeset.action.name not in AshPaperTrail.Resource.Info.ignore_actions(changeset.resource) &&
      (changeset.action_type == :create ||
         (changeset.action_type == :destroy &&
            AshPaperTrail.Resource.Info.create_version_on_destroy?(changeset.resource)) ||
         (changeset.action_type == :update &&
            changeset.action.name in AshPaperTrail.Resource.Info.on_actions(changeset.resource)))
  end

  defp create_new_version(changeset) do
    Ash.Changeset.after_action(changeset, fn changeset, result ->
      changed? = changed?(changeset)

      if changeset.action_type == :create ||
           (changeset.action_type == :destroy &&
              AshPaperTrail.Resource.Info.create_version_on_destroy?(changeset.resource)) ||
           (changeset.action_type == :update && changed?) do
        {version_changeset, input, actor} = build_notifications(changeset, result)
        create!(changeset, version_changeset, input, actor)
        {:ok, result}
      else
        {:ok, result}
      end
    end)
  end

  defp bulk_build_notifications(changesets_and_results) do
    changesets_and_results
    |> Enum.filter(fn {changeset, _result} ->
      changed? = changed?(changeset)

      changeset.action_type == :create ||
        (changeset.action_type == :destroy &&
           AshPaperTrail.Resource.Info.create_version_on_destroy?(changeset.resource)) ||
        (changeset.action_type == :update && changed?)
    end)
    |> Enum.map(fn {changeset, result} -> build_notifications(changeset, result, bulk?: true) end)
    |> Enum.reduce([], fn input, inputs -> [input | inputs] end)
  end

  defp changed?(changeset) do
    if changeset.action_type == :update do
      if AshPaperTrail.Resource.Info.only_when_changed?(changeset.resource) do
        changeset.context.changed?
      else
        !(changeset.context[:skip_version_when_unchanged?] && !changeset.context.changed?)
      end
    else
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

    actor = changeset.context[:private][:actor]

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

    action_input_attrs =
      changeset.action.accept
      |> Enum.map(fn attr_name ->
        attr_info = Ash.Resource.Info.attribute(changeset.resource, attr_name)
        {present, params_value} = get_raw_params_value_if_present(changeset.params, attr_name)

        %{
          name: attr_name,
          type: :attribute,
          ash_type: attr_info.type,
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
          present?: present,
          params_value: params_value,
          sensitive?: arg.sensitive?
        }
      end)

    action_inputs =
      if AshPaperTrail.Resource.Info.store_action_inputs?(changeset.resource) do
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
                  Ash.Type.NewType.constraints(input.ash_type, [])
                else
                  Ash.Type.constraints(input.ash_type)
                end

              case Ash.Type.dump_to_embedded(input.ash_type, input_value, constraints) do
                {:ok, value} ->
                  casted_params_value = extract_casted_params_values(value, input.params_value)
                  Map.put(action_inputs, input.name, casted_params_value)

                :error ->
                  raise "Unable to serialize input value for #{input.name}"
              end
          end
        end)
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
      |> Map.merge(%{
        version_source_id: Map.get(result, hd(Ash.Resource.Info.primary_key(changeset.resource))),
        version_action_type: changeset.action.type,
        version_action_name: changeset.action.name,
        version_action_inputs: action_inputs,
        version_resource_identifier:
          AshPaperTrail.Resource.Info.resource_identifier(changeset.resource),
        changes: changes
      })

    if Keyword.get(opts, :bulk?) do
      input
    else
      {Ash.Changeset.new(version_resource), input, actor}
    end
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
      context: %{ash_paper_trail?: true},
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
    |> Ash.Changeset.set_context(%{ash_paper_trail?: true})
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
