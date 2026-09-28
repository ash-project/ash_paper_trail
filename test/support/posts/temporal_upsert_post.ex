# SPDX-FileCopyrightText: 2022 ash_paper_trail contributors <https://github.com/ash-project/ash_paper_trail/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshPaperTrail.Test.Posts.TemporalUpsertPost do
  @moduledoc """
  A temporal resource versioned in `:temporal_inline` mode that is written to with upserts.

  Kept separate from `TemporalPost` because the identity's `pre_check_with` adds a
  `before_action` hook, which rules out atomic updates.
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
    change_tracking_mode :changes_only
    store_action_name? true
    ignore_attributes [:inserted_at, :updated_at]

    belongs_to_actor :user, AshPaperTrail.Test.Accounts.User,
      domain: AshPaperTrail.Test.Accounts.Domain

    metadata :reason_for_change, :string
  end

  code_interface do
    define :read
    define :upsert
  end

  actions do
    default_accept :*
    defaults [:read]

    create :upsert do
      upsert? true
      upsert_identity :unique_subject
      upsert_fields [:body]
    end
  end

  identities do
    identity :unique_subject, [:subject], pre_check_with: AshPaperTrail.Test.Posts.Domain
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

    attribute :views, :integer do
      public? true
      default 0
      allow_nil? false
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end
end
