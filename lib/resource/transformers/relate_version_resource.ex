# SPDX-FileCopyrightText: 2022 ash_paper_trail contributors <https://github.com/ash-project/ash_paper_trail/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshPaperTrail.Resource.Transformers.RelateVersionResource do
  @moduledoc "Relates the resource to its created version resource"
  use Spark.Dsl.Transformer
  alias Spark.Dsl.Transformer

  def transform(dsl_state) do
    primary_keys = Ash.Resource.Info.primary_key(dsl_state)

    with :ok <- validate_primary_keys(primary_keys),
         {:ok, relationship} <- build_has_many(dsl_state, primary_keys) do
      {:ok,
       Transformer.add_entity(dsl_state, [:relationships], %{
         relationship
         | source: Transformer.get_persisted(dsl_state, :module)
       })}
    end
  end

  def before?(Ash.Resource.Transformers.SetRelationshipSource), do: true
  def before?(_), do: false

  def after?(_), do: true

  defp validate_primary_keys([]) do
    {:error, "Resources must have a primary key to use paper trail"}
  end

  defp validate_primary_keys(_keys), do: :ok

  defp build_has_many(dsl_state, primary_keys) do
    {default_opts, filter} =
      case primary_keys do
        [key] ->
          {[
             name: AshPaperTrail.Resource.Info.versions_relationship_name(dsl_state),
             destination: AshPaperTrail.Resource.Info.version_resource(dsl_state),
             destination_attribute: :version_source_id,
             source_attribute: key
           ], nil}

        _keys ->
          {[
             name: AshPaperTrail.Resource.Info.versions_relationship_name(dsl_state),
             destination: AshPaperTrail.Resource.Info.version_resource(dsl_state),
             no_attributes?: true
           ], AshPaperTrail.Resource.PrimaryKey.source_versions_filter(dsl_state)}
      end

    opts =
      default_opts
      |> Keyword.merge(AshPaperTrail.Resource.Info.relationship_opts(dsl_state))

    with {:ok, relationship} <-
           Transformer.build_entity(
             Ash.Resource.Dsl,
             [:relationships],
             :has_many,
             opts
           ) do
      {:ok, maybe_put_filter(relationship, filter)}
    end
  end

  defp maybe_put_filter(relationship, nil), do: relationship

  defp maybe_put_filter(relationship, filter) do
    %{relationship | filter: filter}
  end
end
