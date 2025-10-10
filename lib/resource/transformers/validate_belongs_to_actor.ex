# SPDX-FileCopyrightText: 2020 Zach Daniel
#
# SPDX-License-Identifier: MIT

defmodule AshPaperTrail.Resource.Transformers.ValidateBelongsToActor do
  @moduledoc "Validates that when multiple belongs_to_actor options are defined that they all allow_nil? true"
  use Spark.Dsl.Transformer

  def transform(dsl_state) do
    with entities <- Spark.Dsl.Transformer.get_entities(dsl_state, [:paper_trail]),
         belongs_to_actors when length(belongs_to_actors) > 1 <-
           Enum.filter(entities, fn
             %AshPaperTrail.Resource.BelongsToActor{} -> true
             _ -> false
           end),
         false <-
           Enum.all?(belongs_to_actors, & &1.allow_nil?) do
      {:error, "when declaring multiple belongs_to_actors, they all must allow_nil?"}
    else
      _ ->
        {:ok, dsl_state}
    end
  end
end
