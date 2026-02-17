# SPDX-FileCopyrightText: 2022 ash_paper_trail contributors <https://github.com/ash-project/ash_paper_trail/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshPaperTrail.Resource.Metadata do
  @moduledoc "Represents a metadata attribute on a version resource"

  defstruct [
    :__spark_metadata__,
    :name,
    :type,
    :constraints,
    :allow_nil?
  ]

  @type t :: %__MODULE__{
          __spark_metadata__: Spark.Dsl.Entity.spark_meta(),
          name: atom,
          type: term,
          constraints: keyword,
          allow_nil?: boolean
        }

  @schema [
    name: [
      type: :atom,
      required: true,
      doc: "The name of the metadata attribute on the version resource."
    ],
    type: [
      type: :any,
      required: true,
      doc: "The type of the metadata attribute. See `Ash.Type` for more."
    ],
    constraints: [
      type: :keyword_list,
      default: [],
      doc: "Type constraints for the metadata attribute."
    ],
    allow_nil?: [
      type: :boolean,
      default: true,
      doc: "Whether or not the metadata may be `nil`."
    ]
  ]

  @doc false
  def schema, do: @schema
end
