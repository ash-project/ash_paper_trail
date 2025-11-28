# SPDX-FileCopyrightText: 2022 ash_paper_trail contributors <https://github.com/ash-project/ash_paper_trail/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshPaperTrail.Test.Posts.FullDiffPost do
  @moduledoc """
    A page is like a post but uses the change_tracking_mode :full_diff
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
    attributes_as_attributes [:subject, :body, :tenant]
    change_tracking_mode :full_diff
  end

  code_interface do
    define :create
    define :read
    define :update
    define :destroy
    define :publish
  end

  actions do
    default_accept :*
    defaults [:create, :read, :update, :destroy]

    update :publish do
      require_atomic? false
      accept []
      change set_attribute(:published, true)
    end
  end

  attributes do
    uuid_primary_key :id, writable?: true

    attribute :tenant, :string, public?: true

    attribute :subject, :string, default: "", public?: true

    attribute :body, :string, default: "", public?: true

    attribute :secret, :string, public?: true

    attribute :author, AshPaperTrail.Test.Posts.Author do
      public? true
      allow_nil? true
    end

    attribute :tags, {:array, AshPaperTrail.Test.Posts.Tag} do
      public? true
      allow_nil? true
    end

    attribute :moderator_reaction, AshPaperTrail.Test.Posts.Reaction do
      public? true
      allow_nil? true
    end

    attribute :reactions, {:array, AshPaperTrail.Test.Posts.Reaction} do
      public? true
      allow_nil? false
      default []
    end

    attribute :source, AshPaperTrail.Test.Posts.Source do
      public? true
      allow_nil? true
    end

    attribute :references, {:array, AshPaperTrail.Test.Posts.Source} do
      public? true
      allow_nil? true
    end

    attribute :published, :boolean do
      public? true
      allow_nil? false
      default false
    end

    attribute :seo_map, :map do
      public? true
      allow_nil? true
    end

    attribute :views, :integer do
      public? true
      allow_nil? false
      default 0
    end

    attribute :lucky_numbers, {:array, :integer} do
      public? true
      allow_nil? true
    end

    attribute :times, {:array, :time} do
      public? true
      allow_nil? true
    end
  end
end
