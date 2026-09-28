# SPDX-FileCopyrightText: 2022 ash_paper_trail contributors <https://github.com/ash-project/ash_paper_trail/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshPaperTrail.Test.Posts.TemporalPreviousValuesPost do
  @moduledoc """
  A temporal resource versioned in `:temporal_inline` mode with `:previous_values` tracking.
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
    change_tracking_mode :previous_values
    ignore_attributes [:inserted_at, :updated_at]
  end

  code_interface do
    define :create
    define :read
    define :update
    define :increment_views
  end

  actions do
    default_accept :*
    defaults [:read, create: :*, update: :*]

    update :increment_views do
      accept [:body]
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

    attribute :views, :integer do
      public? true
      default 0
      allow_nil? false
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end
end
