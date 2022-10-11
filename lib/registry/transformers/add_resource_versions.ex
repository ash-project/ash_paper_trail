defmodule AshPaperTrail.Registry.Transformers.AddResourceVersions do
  @moduledoc "Adds any version resources to the api for any resources"
  use Spark.Dsl.Transformer
  alias Spark.Dsl.Transformer

  @before_transformers [
    Ash.Registry.ResourceValidations.Transformers.ValidateRelatedResourceInclusion,
    Ash.Registry.ResourceValidations.Transformers.EnsureResourcesCompiled
  ]

  def before?(transformer) when transformer in @before_transformers,
    do: true

  def before?(_), do: false

  def transform(dsl_state) do
    dsl_state
    |> Ash.Registry.Info.entries()
    |> Enum.reduce({:ok, dsl_state}, fn resource, {:ok, dsl_state} ->
      if AshPaperTrail.Resource in Spark.extensions(resource) do
        version = AshPaperTrail.Resource.Info.version_resource(resource)

        {:ok, entry} =
          Transformer.build_entity(Ash.Registry.Dsl, [:entries], :entry,
            entry: Code.ensure_compiled!(version)
          )

        {:ok, Transformer.add_entity(dsl_state, [:entries], entry)}
      else
        {:ok, dsl_state}
      end
    end)
  end
end
