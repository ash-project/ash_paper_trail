defmodule AshPaperTrail.Api.Transformers.AllowResourceVersions do
  @moduledoc """
  Adds any version resources to the api for any resources. An alternative to
  AshPaperTrail.Api.Transfomers.AllowResourceVersions.
  """

  use Spark.Dsl.Transformer
  alias Spark.Dsl.Transformer

  def before?(_), do: false

  def transform(dsl_state) do
    existing_allow_mfa = Ash.Api.Info.allow(dsl_state)

    {:ok,
     Transformer.set_option(
       dsl_state,
       [:resources],
       :allow,
       {AshPaperTrail, :allow_resource_versions, [existing_allow_mfa]}
     )}
  end
end
