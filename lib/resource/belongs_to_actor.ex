defmodule AshPaperTrail.Resource.BelongsToActor do
  @moduledoc "Represents a belongs_to_actor relationship on a version resource"

  defstruct [
    :allow_nil?,
    :api,
    :attribute_type,
    :destination,
    :define_attribute?,
    :name
  ]

  @type t :: %__MODULE__{
          allow_nil?: boolean,
          api: atom,
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
    api: [
      type: :atom,
      doc: """
      The API module to use when working with the related entity.
      """
    ],
    attribute_type: [
      type: :any,
      default: Application.compile_env(:ash, :default_belongs_to_type, :uuid),
      doc: "The type of the generated created attribute. See `Ash.Type` for more."
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
