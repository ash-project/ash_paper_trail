# SPDX-FileCopyrightText: 2020 Zach Daniel
#
# SPDX-License-Identifier: MIT

defmodule AshPaperTrail.Resource do
  @moduledoc """
  Documentation for `AshPaperTrail.Resource`.
  """

  @belongs_to_actor %Spark.Dsl.Entity{
    name: :belongs_to_actor,
    describe: """
    Creates a belongs_to relationship for the actor resource. When creating a new version, if the actor on the action is set and
    matches the resource type, the version will be related to the actor. If your actors are polymorphic or varying types, declare a
    belongs_to_actor for each type.

    A reference is also created with `on_delete: :nilify` and `on_update: :update`

    If you need more complex relationships, set `define_attribute? false` and add the relationship via a mixin.

    If your actor is not a resource, add a mixin and with a change for all creates that sets the actor's to one your attributes.
    The actor on the version changeset is set.
    """,
    examples: [
      "belongs_to_actor :user, MyApp.Users.User, domain: MyApp.Users"
    ],
    no_depend_modules: [:destination, :domain],
    target: AshPaperTrail.Resource.BelongsToActor,
    args: [:name, :destination],
    schema: AshPaperTrail.Resource.BelongsToActor.schema()
  }

  @paper_trail %Spark.Dsl.Section{
    name: :paper_trail,
    describe: """
    A section for configuring how versioning is derived for the resource.
    """,
    entities: [@belongs_to_actor],
    schema: [
      primary_key_type: [
        type: :atom,
        default: :uuid,
        doc: "Set the type of the column `:id`."
      ],
      attributes_as_attributes: [
        type: {:list, :atom},
        default: [],
        doc: """
        A set of attributes that should be set as attributes on the version resource, instead of stored in the freeform `changes` map attribute.
        """
      ],
      only_when_changed?: [
        type: :boolean,
        default: true,
        doc: """
        Set to false to create version records for actions even when nothing about the data has changed.
        """
      ],
      change_tracking_mode: [
        type: {:one_of, [:snapshot, :changes_only, :full_diff]},
        default: :snapshot,
        doc:
          "Changes are stored in a map attribute called `changes`.  The `change_tracking_mode` determines what's stored. See the getting started guide for more."
      ],
      ignore_attributes: [
        type: {:list, :atom},
        default: [],
        doc: """
        A list of attributes that should be ignored. Typically you'll want to ignore your timestamps. The primary key is always ignored.
        """
      ],
      sensitive_attributes: [
        type: {:in, [:display, :ignore, :redact]},
        default: :display,
        doc: """
        Controls the behaviour when sensitive attributes are being versioned. By default their values are versioned, but they can be redacted so that you know they changed without knowing the values.
        """
      ],
      ignore_actions: [
        type: {:list, :atom},
        default: [],
        doc: """
        A list of actions that should not produce new versions. By default, no actions are ignored.
        """
      ],
      mixin: [
        type: {:or, [:atom, :mfa]},
        default: nil,
        doc: """
        A module that defines a `using` macro or {module, function, arguments} tuple that will be mixed into the version resource.
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
        doc:
          "Whether or not to create a foreign key reference from the version to the source.  This should be set to `false` if you are allowing actual deletion of data. Only relevant for resources using the AshPostgres data layer."
      ],
      relationship_opts: [
        type: :keyword_list,
        doc:
          "Options to pass to the has_many :paper_trail_versions relationship that is created on this resource. For example, `public?: true` to expose the relationship over graphql. See `d:Ash.Resource.Dsl.relationships.has_many`."
      ],
      store_action_name?: [
        type: :boolean,
        default: false,
        doc:
          "Whether or not to add the `version_action_name` attribute to the  version resource. This is useful for auditing purposes. The `version_action_type` attribute is always stored."
      ],
      store_action_inputs?: [
        type: :boolean,
        default: false,
        doc:
          "Whether or not to add the `version_action_inputs` attribute to the version resource, which will store all attributes and arguments for the called action, redacting any sensitive values. This is useful for auditing purposes. The `version_action_inputs` attribute is always stored."
      ],
      create_version_on_destroy?: [
        type: :boolean,
        default: true,
        doc:
          "Whether or not to create a version on destroy. You will need to set this to `false` unless you are doing soft destroys (like with `AshArchival`)"
      ],
      store_resource_identifier?: [
        type: :boolean,
        default: false,
        doc:
          "Whether or not to add the `version_resource_identifier` attribute to the version resource. This is useful for auditing purposes."
      ],
      resource_identifier: [
        type: :atom,
        doc:
          "A name to use for this resource in the `version_resource_identifier`. Defaults to `Ash.Resource.Info.short_name/1`."
      ],
      version_extensions: [
        type: :keyword_list,
        default: [],
        doc: """
        Extensions that should be used by the version resource. For example: `extensions: [AshGraphql.Resource], notifier: [Ash.Notifiers.PubSub]`
        """
      ],
      table_name: [
        type: :string,
        required: false,
        doc: """
        The table to use to store versions if using a SQL-based data layer, derived if not set
        """
      ],
      public_timestamps?: [
        type: :boolean,
        default: false,
        doc: """
        Whether of not to make the version resource's timestamps public
        """
      ]
    ]
  }

  use Spark.Dsl.Extension,
    sections: [@paper_trail],
    transformers: [
      AshPaperTrail.Resource.Transformers.ValidateBelongsToActor,
      AshPaperTrail.Resource.Transformers.RelateVersionResource,
      AshPaperTrail.Resource.Transformers.CreateVersionResource,
      AshPaperTrail.Resource.Transformers.VersionOnChange
    ]
end
