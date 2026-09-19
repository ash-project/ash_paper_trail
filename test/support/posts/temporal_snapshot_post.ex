# SPDX-FileCopyrightText: 2022 ash_paper_trail contributors <https://github.com/ash-project/ash_paper_trail/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshPaperTrail.Test.Posts.TemporalSnapshotPost do
  @moduledoc """
  A temporal resource versioned in `:temporal_inline` mode with `:snapshot` tracking, which
  records a version even when nothing changed.
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
    change_tracking_mode :snapshot
    only_when_changed? false
    store_action_inputs? true
    public_version_attributes([:version_action_type])
  end

  code_interface do
    define :create
    define :read
    define :update
  end

  actions do
    default_accept :*
    defaults [:read, create: :*, update: :*]
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
  end
end
