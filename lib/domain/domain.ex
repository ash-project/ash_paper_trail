defmodule AshPaperTrail.Domain do
  @moduledoc """
  Documentation for `AshPaperTrail.Domain`.
  """

  @paper_trail %Spark.Dsl.Section{
    name: :paper_trail,
    describe: """
    A section for configuring paper_trail behavior at the domain level.
    """,
    schema: [
      include_versions?: [
        type: :boolean,
        default: false,
        doc: "Automatically include all version resources in the domain."
      ]
    ]
  }

  use Spark.Dsl.Extension,
    transformers: [
      AshPaperTrail.Domain.Transformers.AllowResourceVersions
    ],
    sections: [@paper_trail]
end
