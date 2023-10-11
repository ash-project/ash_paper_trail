defmodule AshPaperTrail.Registry do
  @moduledoc "Deprecated in favor of `AshPaperTrail.Api`. Extends a registry to include the versions of paper trail resources. "
  use Spark.Dsl.Extension,
    transformers: [
      AshPaperTrail.Registry.Transformers.AddResourceVersions
    ]
end
