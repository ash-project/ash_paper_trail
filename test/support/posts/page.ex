defmodule AshPaperTrail.Test.Posts.Page do
  @moduledoc """
    A page is like a post but uses the change_tracking_mode :full_diff
  """

  use Ash.Resource,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshPaperTrail.Resource],
    validate_api_inclusion?: false

  ets do
    private? true
  end

  paper_trail do
    attributes_as_attributes [:subject, :body, :tenant]
    change_tracking_mode :full_diff
  end

  code_interface do
    define_for AshPaperTrail.Test.Posts.Api

    define :create
    define :read
    define :update
    define :destroy
    define :publish
  end

  actions do
    defaults [:create, :read, :update, :destroy]

    update :publish do
      accept []
      change set_attribute(:published, true)
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :tenant, :string

    attribute :subject, :string do
      allow_nil? false
    end

    attribute :body, :string do
      allow_nil? false
    end

    attribute :secret, :string do
      private? true
    end

    attribute :author, AshPaperTrail.Test.Posts.Author do
      allow_nil? true
    end

    attribute :tags, {:array, AshPaperTrail.Test.Posts.Tag} do
      allow_nil? false
      default []
    end

    attribute :published, :boolean do
      allow_nil? false
      default false
    end

    attribute :seo_map, :map do
      allow_nil? true
    end

    attribute :views, :integer do
      allow_nil? false
      default 0
    end

    attribute :lucky_numbers, {:array, :integer} do
      allow_nil? true
    end
  end
end
