defmodule AshPaperTrail.Resource.StoreActorInformation do
  @moduledoc "Represents a store_actor_information on a version resource"

  defstruct [
    :attributes,
    :destination,
    :name,
    :public?
  ]

  @type t :: %__MODULE__{
          attributes: {:list, :atom},
          destination: Ash.Resource.t(),
          name: atom,
          public?: boolean
        }

  @schema [
    attributes: [
      type: {:list, :atom},
      doc: "The names of the actor attributes to store (e.g. [:id, :email])",
      required: true
    ],
    destination: [
      type: Ash.OptionsHelpers.ash_resource(),
      doc: "The resource of the actor (e.g. MyApp.Users.User)",
      required: true
    ],
    name: [
      type: :atom,
      doc:
        "The name of the attribute to create on the version resource (default :actor_information)",
      default: :actor_information
    ],
    public?: [
      type: :boolean,
      default: false,
      doc: "Whether this relationship should be included in public interfaces"
    ]
  ]

  @doc false
  def schema, do: @schema
end
