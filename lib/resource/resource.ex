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
      ignore_attributes: [
        type: {:list, :atom},
        default: [],
        doc: """
        A list of attributes that should be ignored. `created_at`, `updated_at` and the primary key are always ignored.
        """
      ],
      attributes_as_attributes: [
        type: {:list, :atom},
        default: [],
        doc: """
        A set of attributes that should be set as attributes on the version resource, instead of stored in the freeform `changes` map attribute.
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
      ],
      version_extensions: [
        type: :keyword_list,
        default: [],
        doc: """
        Extensions that should be used by the version resource. For example: `extensions: [AshGraphql.Resource], notifier: [Ash.Notifiers.PubSub]`
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
      change_tracking_mode: [
        type: {:one_of, [:snapshot, :changes_only, :full_diff]},
        default: :snapshot,
        doc: """
        Changes are stored in a map attribute called `changes`.  The `change_tracking_mode` 
        determines what's stored. Valid options are `:snapshot` and `:changes_only` and `:full_diff`.

        :snapshot will json dump the contents of every attribute whether they changed or not.

        `{ subject: "new subject", body: "unchanged body", author: { name: "bob"}}`

        :changes_only will json dump the contents of only the attributes that have changed. 
        Note if any part of an embedded attribute and array of embedded attributes, changes then
        the entire top level attribute is dumped.

        `{ subject: "new subject" }`

        :full_diff will json dump the contents of each attribute.
        `{ subject: { from: "subject", to: "new subject" }, body: { unchanged: "unchanged_body" }}, author: { changes: { unchanged: "bob" }}`

        """
      ],
      store_action_name?: [
        type: :boolean,
        default: false,
        doc: """
        Whether or not to add the `version_action_name` attribute to the  version resource. This is
        useful for auditing purposes. The `version_action_type` attribute is always stored.
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
