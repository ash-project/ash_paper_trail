defmodule AshPaperTrail.Resource do
  @moduledoc """
  Documentation for `AshPaperTrail.Resource`.
  """

  @versioned %Spark.Dsl.Section{
    name: :versions,
    describe: """
    A section for configuring how versioning is derived for the resource.
    """,
    schema: [
      ignore_attributes: [
        type: {:list, :atom},
        default: [],
        doc: """
        A list of attributes that should be ignored. `created_at`, `updated_at` and the primary key are always ignored.
        """
      ],
      on_actions: [
        type: {:list, :atom},
        doc: """
        Which actions should produce new versions. By default, all create/update actions will produce new versions.
        """
      ],
      mixin: [
        type: :atom,
        default: nil,
        doc: """
        A module that defines a `using` macro that will be mixed into the version resource.
        """
      ]
    ]
  }

  use Spark.Dsl.Extension,
    sections: [@versioned],
    transformers: [
      AshPaperTrail.Resource.Transformers.RelateVersionResource,
      AshPaperTrail.Resource.Transformers.CreateVersionResource,
      AshPaperTrail.Resource.Transformers.VersionOnChange
    ]

  @doc false
  def validate_capture_relationships(value) do
    {:ok,
     value
     |> List.wrap()
     |> Enum.map(fn
       {key, value} ->
         {key, value}

       value ->
         {value, []}
     end)}
  end
end
