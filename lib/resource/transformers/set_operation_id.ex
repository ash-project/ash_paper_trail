# SPDX-FileCopyrightText: 2022 ash_paper_trail contributors <https://github.com/ash-project/ash_paper_trail/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshPaperTrail.Resource.Transformers.SetOperationId do
  @moduledoc """
  When `operation_id_field` is set, adds a change to the front of every create, update and
  destroy action, and a global preparation for read and generic actions, that set the operation
  id in the shared context.

  Global changes run after an action's own changes, so the change is added to each action to
  run first. Global preparations run before an action's own preparations, so one suffices
  there (and adding it to the primary read action would warn).
  """
  use Spark.Dsl.Transformer
  alias Spark.Dsl.Transformer

  def transform(dsl_state) do
    if AshPaperTrail.Resource.Info.operation_id_field(dsl_state) do
      with {:ok, dsl_state} <- add_preparation(dsl_state) do
        dsl_state
        |> Transformer.get_entities([:actions])
        |> Enum.reject(&(&1.type in [:read, :action]))
        |> Enum.reduce_while({:ok, dsl_state}, fn action, {:ok, dsl_state} ->
          case prepend_change(dsl_state, action) do
            {:ok, dsl_state} -> {:cont, {:ok, dsl_state}}
            {:error, error} -> {:halt, {:error, error}}
          end
        end)
      end
    else
      {:ok, dsl_state}
    end
  end

  # Default actions are added by `SetPrimaryActions`, and pipelines are expanded in place by
  # `ResolvePipelines`, so both must happen first for our change to stay at the front.
  def after?(Ash.Resource.Transformers.SetPrimaryActions), do: true
  def after?(Ash.Resource.Transformers.ResolvePipelines), do: true
  def after?(_), do: false

  defp add_preparation(dsl_state) do
    with {:ok, preparation} <-
           Transformer.build_entity(Ash.Resource.Dsl, [:preparations], :prepare,
             preparation: AshPaperTrail.Resource.Preparations.SetOperationId,
             on: [:read, :action]
           ) do
      {:ok, Transformer.add_entity(dsl_state, [:preparations], preparation, type: :prepend)}
    end
  end

  defp prepend_change(dsl_state, %{type: type} = action) do
    with {:ok, change} <-
           Transformer.build_entity(Ash.Resource.Dsl, [:actions, type], :change,
             change: AshPaperTrail.Resource.Changes.SetOperationId
           ) do
      replace(dsl_state, %{action | changes: [change | action.changes]})
    end
  end

  defp replace(dsl_state, action) do
    {:ok,
     Transformer.replace_entity(
       dsl_state,
       [:actions],
       action,
       &(&1.name == action.name && &1.type == action.type)
     )}
  end
end
