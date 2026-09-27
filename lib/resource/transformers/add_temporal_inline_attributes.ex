# SPDX-FileCopyrightText: 2022 ash_paper_trail contributors <https://github.com/ash-project/ash_paper_trail/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshPaperTrail.Resource.Transformers.AddTemporalInlineAttributes do
  @moduledoc """
  In `mode :temporal_inline`, adds the version attributes and actor relationships to the
  resource itself instead of generating a version resource.
  """
  use Spark.Dsl.Transformer
  alias AshPaperTrail.Resource.Info
  alias Spark.Dsl.Transformer

  def transform(dsl_state) do
    if Info.temporal_inline?(dsl_state) do
      add_all(dsl_state)
    else
      {:ok, dsl_state}
    end
  end

  def before?(Ash.Resource.Transformers.BelongsToAttribute), do: true
  def before?(Ash.Resource.Transformers.SetRelationshipSource), do: true
  def before?(_), do: false

  defp add_all(dsl_state) do
    public = Info.public_version_attributes(dsl_state)
    ignore_attributes = Info.ignore_attributes(dsl_state)

    sensitive_changes? =
      dsl_state
      |> Ash.Resource.Info.attributes()
      |> Enum.reject(&(&1.name in ignore_attributes))
      |> Enum.any?(& &1.sensitive?)

    attributes =
      [
        {:version_action_type, :atom,
         constraints: [one_of: [:create, :update]],
         description: "The type of the action that produced this version"},
        if Info.store_action_name?(dsl_state) do
          {:version_action_name, :atom,
           constraints: [unsafe_to_atom?: true],
           description: "The name of the action that produced this version"}
        end,
        if Info.store_action_inputs?(dsl_state) do
          {:version_action_inputs, :map,
           description: "The inputs of the action that produced this version"}
        end,
        if Info.change_tracking_mode(dsl_state) != :snapshot do
          {:changes, :map,
           sensitive?: sensitive_changes?,
           description: "The changes made by the action that produced this version"}
        end
      ]
      |> Enum.reject(&is_nil/1)
      |> Enum.concat(
        Enum.map(Info.metadata(dsl_state), fn meta ->
          {meta.name, meta.type, constraints: meta.constraints, allow_nil?: meta.allow_nil?}
        end)
      )
      |> Enum.map(fn {name, type, opts} ->
        {name, type, Keyword.put(opts, :public?, name in public)}
      end)

    with {:ok, dsl_state} <- add_attributes(dsl_state, attributes) do
      add_actor_relationships(dsl_state, Info.belongs_to_actor(dsl_state))
    end
  end

  defp add_attributes(dsl_state, attributes) do
    Enum.reduce_while(attributes, {:ok, dsl_state}, fn {name, type, opts}, {:ok, dsl_state} ->
      if Ash.Resource.Info.attribute(dsl_state, name) do
        {:halt, {:error, conflict(dsl_state, :attribute, name)}}
      else
        opts =
          Keyword.merge(
            [name: name, type: type, writable?: false, allow_nil?: true],
            opts
          )

        case Transformer.build_entity(Ash.Resource.Dsl, [:attributes], :attribute, opts) do
          {:ok, attribute} ->
            {:cont, {:ok, Transformer.add_entity(dsl_state, [:attributes], attribute)}}

          {:error, error} ->
            {:halt, {:error, error}}
        end
      end
    end)
  end

  defp add_actor_relationships(dsl_state, belongs_to_actors) do
    Enum.reduce_while(belongs_to_actors, {:ok, dsl_state}, fn actor, {:ok, dsl_state} ->
      if Ash.Resource.Info.relationship(dsl_state, actor.name) do
        {:halt, {:error, conflict(dsl_state, :relationship, actor.name)}}
      else
        with {:ok, dsl_state} <- add_actor_relationship(dsl_state, actor),
             {:ok, dsl_state} <- add_actor_reference(dsl_state, actor) do
          {:cont, {:ok, dsl_state}}
        else
          {:error, error} -> {:halt, {:error, error}}
        end
      end
    end)
  end

  defp add_actor_relationship(dsl_state, actor) do
    with {:ok, relationship} <-
           Transformer.build_entity(Ash.Resource.Dsl, [:relationships], :belongs_to,
             name: actor.name,
             destination: actor.destination,
             domain: actor.domain,
             define_attribute?: actor.define_attribute?,
             allow_nil?: actor.allow_nil?,
             attribute_type: actor.attribute_type,
             attribute_public?:
               Info.actor_source_attribute(dsl_state, actor) in Info.public_version_attributes(
                 dsl_state
               ),
             attribute_writable?: false,
             public?: actor.public?,
             temporal_keys:
               {Ash.Resource.Info.temporal_attribute(dsl_state), actor.temporal_period}
           ) do
      {:ok,
       Transformer.add_entity(dsl_state, [:relationships], %{
         relationship
         | source: Transformer.get_persisted(dsl_state, :module)
       })}
    end
  end

  defp add_actor_reference(dsl_state, %{define_attribute?: false}), do: {:ok, dsl_state}

  defp add_actor_reference(dsl_state, actor) do
    case references_section(Ash.DataLayer.data_layer(dsl_state)) do
      nil ->
        {:ok, dsl_state}

      {extension, path} ->
        existing? =
          dsl_state
          |> Transformer.get_entities(path)
          |> Enum.any?(&(Map.get(&1, :relationship) == actor.name))

        if existing? do
          {:ok, dsl_state}
        else
          # A temporal actor is referenced by a `PERIOD` foreign key, which only supports
          # `NO ACTION` on update.
          on_update = if actor.temporal_period, do: [], else: [on_update: :update]

          with {:ok, reference} <-
                 Transformer.build_entity(
                   extension,
                   path,
                   :reference,
                   [relationship: actor.name, on_delete: actor.on_delete] ++ on_update
                 ) do
            {:ok, Transformer.add_entity(dsl_state, path, reference)}
          end
        end
    end
  end

  defp references_section(AshPostgres.DataLayer),
    do: {AshPostgres.DataLayer, [:postgres, :references]}

  defp references_section(AshSqlite.DataLayer), do: {AshSqlite.DataLayer, [:sqlite, :references]}
  defp references_section(_), do: nil

  defp conflict(dsl_state, kind, name) do
    Spark.Error.DslError.exception(
      module: Transformer.get_persisted(dsl_state, :module),
      path: [:paper_trail, :mode],
      message: """
      `mode :temporal_inline` adds #{kind} `#{name}` to the resource, but one already exists.

      Remove or rename the existing #{kind}.
      """
    )
  end
end
