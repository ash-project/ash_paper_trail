defmodule AshPaperTrail.Domain do
  @moduledoc """
  Documentation for `AshPaperTrail.Domain`.
  """

  use Spark.Dsl.Extension,
    transformers: [
      AshPaperTrail.Domain.Transformers.AllowResourceVersions
    ]
end
