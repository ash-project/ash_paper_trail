defmodule AshPaperTrail.Registry do
  use Spark.Dsl.Extension,
    transformers: [
      AshPaperTrail.Registry.Transformers.AddResourceVersions
    ]
end
