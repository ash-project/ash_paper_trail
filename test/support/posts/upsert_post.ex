# SPDX-FileCopyrightText: 2020 Zach Daniel
#
# SPDX-License-Identifier: MIT

defmodule AshPaperTrail.Test.Posts.UpsertPost do
  @moduledoc """
  A test resource for upsert operations with only_when_changed? true
  """

  use Ash.Resource,
    domain: AshPaperTrail.Test.Posts.Domain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshPaperTrail.Resource],
    validate_domain_inclusion?: false

  ets do
    private? true
  end

  paper_trail do
    primary_key_type :uuid
    attributes_as_attributes [:subject, :body]
    change_tracking_mode :changes_only
    only_when_changed?(true)
  end

  code_interface do
    define :create
    define :read
    define :upsert
  end

  actions do
    default_accept :*
    defaults [:create, :read]

    create :upsert do
      upsert? true
      upsert_identity :unique_subject
      upsert_fields [:body]
      upsert_condition expr(body != ^atomic_ref(:body))
      return_skipped_upsert? true
    end
  end

  identities do
    identity :unique_subject, [:subject], pre_check_with: AshPaperTrail.Test.Posts.Domain
  end

  attributes do
    uuid_primary_key :id, writable?: true

    attribute :subject, :string do
      public? true
      allow_nil? false
    end

    attribute :body, :string do
      public? true
      allow_nil? false
    end
  end
end
