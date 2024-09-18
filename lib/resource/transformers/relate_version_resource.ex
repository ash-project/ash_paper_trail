defmodule AshPaperTrail.Resource.Transformers.RelateVersionResource do
  @moduledoc "Relates the resource to its created version resource"
  use Spark.Dsl.Transformer
  alias Spark.Dsl.Transformer

  import Ash.Expr

  # sobelow_skip ["DOS.StringToAtom"]
  def transform(dsl_state) do
    with :ok <- validate_source_attribute(dsl_state),
         {:ok, relationship} <- build_has_many(dsl_state) do
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
      [] ->
        {:error,
         "Only resources with a primary key are currently supported. Got keys #{inspect(keys)}"}

      _ ->
        :ok
    end
  end

  defp build_has_many(dsl_state) do
    pkey_fields = Ash.Resource.Info.primary_key(dsl_state)
    default_opts = AshPaperTrail.Resource.Info.relationship_opts(dsl_state)

    {first_pkey, rest_pkey} =
      case pkey_fields do
        [field] ->
          {field, []}

        multiple ->
          if source_attribute = default_opts[:source_attribute] do
            {source_attribute, multiple -- [source_attribute]}
          else
          end
      end

    default_opts = [
      name: :paper_trail_versions,
      destination: AshPaperTrail.Resource.Info.version_resource(dsl_state),
      destination_attribute: :version_source_id,
      source_attribute: first_pkey
    ]

    opts =
      default_opts
      |> Keyword.merge(default_opts)

    opts =
      if Enum.empty?(rest_pkey) do
        opts
      else
        filter = build_filter(rest_pkey)

        Keyword.update(opts, :filter, filter, &[filter | &1])
      end

    Transformer.build_entity(
      Ash.Resource.Dsl,
      [:relationships],
      :has_many,
      opts
    )
  end

  defp build_filter(fields, acc \\ nil)
  defp build_filter([], acc), do: acc

  defp build_filter([field | rest], acc) do
    new_acc =
      if is_nil(acc) do
        expr(^ref(field) == parent(^ref(field)))
      else
        expr(^acc && ^ref(field) == parent(^ref(field)))
      end

    build_filter(rest, new_acc)
  end
end
