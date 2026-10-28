# SPDX-FileCopyrightText: 2022 ash_paper_trail contributors <https://github.com/ash-project/ash_paper_trail/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshPaperTrail.Test.Posts.TemporalPost do
  @moduledoc """
  A temporal resource versioned in `:temporal_inline` mode with `:changes_only` tracking.
  """

  use Ash.Resource,
    domain: AshPaperTrail.Test.Posts.Domain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshPaperTrail.Resource],
    validate_domain_inclusion?: false

  ets do
    private? true
  end

  temporal do
    strategy :context
    attribute :valid_at
  end

  paper_trail do
    mode(:temporal_inline)
    version_resource?(true)
    change_tracking_mode :changes_only
    store_action_name? true
    ignore_attributes [:inserted_at, :updated_at]
    ignore_actions [:ignored_update]

    belongs_to_actor :user, AshPaperTrail.Test.Accounts.User,
      domain: AshPaperTrail.Test.Accounts.Domain

    metadata :reason_for_change, :string
  end

  code_interface do
    define :create
    define :read
    define :update
    define :destroy
    define :silent_update
    define :ignored_update
    define :increment_views
    define :increment_views_in_hook
    define :reassign, args: [:editor_id]
    define :create_with_editor
    define :archive
  end

  actions do
    default_accept :*
    defaults [:read, :destroy, create: :*, update: :*]

    update :silent_update do
      change set_context(%{ash_paper_trail_disabled?: true})
    end

    update :ignored_update do
    end

    update :increment_views do
      accept []
      change atomic_update(:views, expr(views + 1))
    end

    # Not atomic, so `increment` sets `views` in a `before_action` hook.
    update :increment_views_in_hook do
      require_atomic? false
      accept []
      change increment(:views)
    end

    update :non_atomic_update do
      require_atomic? false
    end

    update :update_nothing do
      require_atomic? false
      accept []
    end

    # Ash sets `editor_id` just before the write.
    update :reassign do
      require_atomic? false
      accept []
      argument :editor_id, :uuid, allow_nil?: false
      change manage_relationship(:editor_id, :editor, type: :append_and_remove)
    end

    create :create_with_editor do
      argument :editor_id, :uuid, allow_nil?: false
      change manage_relationship(:editor_id, :editor, type: :append_and_remove)
    end

    # Written as an update, like AshArchival's archive.
    destroy :archive do
      soft? true
      change set_attribute(:archived_at, &DateTime.utc_now/0)
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :subject, :string do
      public? true
      allow_nil? false
    end

    attribute :body, :string do
      public? true
    end

    attribute :secret, :string do
      public? true
      sensitive? true
    end

    attribute :views, :integer do
      public? true
      default 0
      allow_nil? false
    end

    attribute :archived_at, :utc_datetime_usec do
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :editor, AshPaperTrail.Test.Accounts.User do
      domain AshPaperTrail.Test.Accounts.Domain
      public? true
      temporal_keys {:valid_at, nil}
    end
  end
end
