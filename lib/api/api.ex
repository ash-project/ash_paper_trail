defmodule AshPaperTrail.Api do
  @moduledoc """
  Documentation for `AshPaperTrail.Api`.
  """

  use Spark.Dsl.Extension,
    transformers: [
      AshPaperTrail.Api.Transformers.AllowResourceVersions
    ]
end
