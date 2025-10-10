# SPDX-FileCopyrightText: 2020 Zach Daniel
#
# SPDX-License-Identifier: MIT

defmodule AshPaperTrail.Resource.BelongsToActor do
  @moduledoc "Represents a belongs_to_actor relationship on a version resource"

  defstruct [
    :__spark_metadata__,
    :allow_nil?,
    :domain,
    :attribute_type,
    :destination,
    :define_attribute?,
    :public?,
    :name
  ]

  @type t :: %__MODULE__{
          __spark_metadata__: Spark.Dsl.Entity.spark_meta(),
          allow_nil?: boolean,
          public?: boolean,
          domain: atom,
          attribute_type: term,
          destination: Ash.Resource.t(),
          define_attribute?: boolean,
          name: atom
        }

  @schema [
    name: [
      type: :atom,
      doc: "The name of the relationship to use for the actor (e.g. :user)",
      required: true
    ],
    allow_nil?: [
      type: :boolean,
      default: true,
      doc:
        "Whether this relationship must always be present, e.g: must be included on creation, and never removed (it may be modified). The generated attribute will not allow nil values."
    ],
    domain: [
      type: :atom,
      doc: """
      The Domain module to use when working with the related entity.
      """
    ],
    attribute_type: [
      type: :any,
      default: Application.compile_env(:ash, :default_belongs_to_type, :uuid),
      doc: "The type of the generated created attribute. See `Ash.Type` for more."
    ],
    public?: [
      type: :boolean,
      default: false,
      doc: "Whether this relationship should be included in public interfaces"
    ],
    define_attribute?: [
      type: :boolean,
      default: true,
      doc:
        "If set to `false` an attribute is not created on the resource for this relationship, and one must be manually added in `attributes`, invalidating many other options."
    ],
    destination: [
      type: Ash.OptionsHelpers.ash_resource(),
      doc: "The resource of the actor (e.g. MyApp.Users.User)"
    ]
  ]

  @doc false
  def schema, do: @schema
end
