defmodule AshPaperTrail.Resource do
  @moduledoc """
  Documentation for `AshPaperTrail.Resource`.
  """

  @paper_trail %Spark.Dsl.Section{
    name: :paper_trail,
    describe: """
    A section for configuring how versioning is derived for the resource.
    """,
    schema: [
      attributes_as_attributes: [
        type: {:list, :atom},
        default: [],
        doc: """
        A set of attributes that should be set as attributes on the version resource, instead of stored in the freeform `changes` map attribute.
        """
      ],
      belongs_to_actor: [
        args: [:relationship_name, :resource],
        doc: """
        Creates a belongs_to relationship to version resource. When creating a new version, if the actor is set and matches the 
        resource type, the version will be related to the actor. If your actors are polymorphic or varying types, declare a 
        belongs_to_actor for each type.

        The relationship created will always be `allow_nil? true` and foreign key constraints (if any) will unassociate 
        if the actor record is deleted. If you need more complex relationship, set `define_attribute? false` and add the
        relationship via a mixin.
        """,
        schema: [
          relationship_name: [
            type: :atom,
            doc: "The name of the relationship to use for the actor (e.g. :user)",
            required: true
          ],
          resource: [
            type: :module,
            doc: "The resource of the actor (e.g. MyApp.Users.User)",
            required: true
          ],
          api: [
            type: :module,
            doc: "The apit of the actor (e.g. MyApp.Users)",
            required: true
          ],
          define_attribute?: [
            type: :boolean,
            default: true,
            doc:
              "If set to `false` an attribute is not created on the resource for this relationship, and one must be manually added in `attributes`, invalidating many other options."
          ]
        ]
      ],
      change_tracking_mode: [
        type: {:one_of, [:snapshot, :changes_only]},
        default: :snapshot,
        doc: """
        The mode to use for change tracking. Valid options are `:snapshot` and `:changes_only`.
        `:snapshot` will store the entire resource in the `changes` attribute, while `:changes_only`
        will only store the attributes that have changed.
        """
      ],
      ignore_attributes: [
        type: {:list, :atom},
        default: [],
        doc: """
        A list of attributes that should be ignored. `created_at`, `updated_at` and the primary key are always ignored.
        """
      ],
      mixin: [
        type: :atom,
        default: nil,
        doc: """
        A module that defines a `using` macro that will be mixed into the version resource.
        """
      ],
      on_actions: [
        type: {:list, :atom},
        doc: """
        Which actions should produce new versions. By default, all create/update actions will produce new versions.
        """
      ],
      reference_source?: [
        type: :boolean,
        default: true,
        doc: """
        Whether or not to create a foreign key reference from the version to the source.
        This should be set to `false` if you are allowing actual deletion of data. Pair
        this extension with `AshArchival` to get soft destroys and referential integrity.

        Only relevant for resources using the AshPostgres data layer.
        """
      ],
      store_action_name?: [
        type: :boolean,
        default: false,
        doc: """
        Whether or not to add the `version_action_name` attribute to the  version resource. This is
        useful for auditing purposes. The `version_action_type` attribute is always stored.
        """
      ],
      version_extensions: [
        type: :keyword_list,
        default: [],
        doc: """
        Extensions that should be used by the version resource. For example: `extensions: [AshGraphql.Resource], notifier: [Ash.Notifiers.PubSub]`
        """
      ]
    ]
  }

  use Spark.Dsl.Extension,
    sections: [@paper_trail],
    transformers: [
      AshPaperTrail.Resource.Transformers.RelateVersionResource,
      AshPaperTrail.Resource.Transformers.CreateVersionResource,
      AshPaperTrail.Resource.Transformers.VersionOnChange
    ]
end
