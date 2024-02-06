defmodule AshPaperTrail.Resource.Transformers.RelateVersionResource do
  @moduledoc "Relates the resource to its created version resource"
  use Spark.Dsl.Transformer
  alias Spark.Dsl.Transformer

  # sobelow_skip ["DOS.StringToAtom"]
  def transform(dsl_state) do
    with {:ok, source_attribute} <- validate_source_attribute(dsl_state),
         {:ok, relationship} <-
           Transformer.build_entity(Ash.Resource.Dsl, [:relationships], :has_many,
             name: :paper_trail_versions,
             destination: AshPaperTrail.Resource.Info.version_resource(dsl_state),
             destination_attribute: :version_source_id,
             source_attribute: source_attribute
           ) do
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

  defp validate_source_attribute(dsl_state) do
    case Ash.Resource.Info.primary_key(dsl_state) do
      [key] ->
        {:ok, key}

      keys ->
        {:error,
         "Only resources with a single primary key are currently supported. Got keys #{inspect(keys)}"}
    end
  end
end
