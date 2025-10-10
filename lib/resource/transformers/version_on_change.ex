# SPDX-FileCopyrightText: 2020 Zach Daniel
#
# SPDX-License-Identifier: MIT

defmodule AshPaperTrail.Resource.Transformers.VersionOnChange do
  @moduledoc "Adds the `CreateNewVersion` change to the resource."
  use Spark.Dsl.Transformer
  alias Spark.Dsl.Transformer

  def transform(dsl_state) do
    case Transformer.build_entity(Ash.Resource.Dsl, [:changes], :change,
           change: AshPaperTrail.Resource.Changes.CreateNewVersion,
           on: [:update, :create, :destroy]
         ) do
      {:ok, change} ->
        {:ok, Transformer.add_entity(dsl_state, [:changes], change, type: :prepend)}

      other ->
        other
    end
  end
end
