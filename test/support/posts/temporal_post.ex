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

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end
end
