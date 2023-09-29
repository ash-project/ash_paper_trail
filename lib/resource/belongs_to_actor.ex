defmodule AshPaperTrail.Resource.BelongsToActor do
  @moduledoc "Represents a belongs_to_actor relationship on a version resource"

  defstruct [
    :name,
    :destination,
    :define_attribute?,
    :api
  ]

  @type t :: %__MODULE__{
          name: atom,
          destination: Ash.Resource.t(),
          define_attribute?: boolean
        }

  @schema [
    name: [
      type: :atom,
      doc: "The name of the relationship to use for the actor (e.g. :user)",
      required: true
    ],
    destination: [
      type: Ash.OptionsHelpers.ash_resource(),
      doc: "The resource of the actor (e.g. MyApp.Users.User)"
    ],
    api: [
      type: :atom,
      doc: """
      The API module to use when working with the related entity.
      """
    ],
    define_attribute?: [
      type: :boolean,
      default: true,
      doc:
        "If set to `false` an attribute is not created on the resource for this relationship, and one must be manually added in `attributes`, invalidating many other options."
    ]
  ]

  @doc false
  def schema, do: @schema

  @doc false
  def transform(belongs_to_actor) do
    {:ok, belongs_to_actor}
  end
end
