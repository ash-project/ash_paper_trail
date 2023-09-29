defmodule AshPaperTrail.Test.Posts.Post do
  use Ash.Resource,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshPaperTrail.Resource],
    validate_api_inclusion?: false

  ets do
    private? true
  end

  paper_trail do
    attributes_as_attributes [:subject, :body, :tenant]
    change_tracking_mode :changes_only
    store_action_name? true
    belongs_to_actor :user, AshPaperTrail.Test.Accounts.User, api: AshPaperTrail.Test.Accounts.Api

    belongs_to_actor :news_feed, AshPaperTrail.Test.Accounts.NewsFeed,
      api: AshPaperTrail.Test.Accounts.Api
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

  multitenancy do
    strategy :attribute
    attribute :tenant
    parse_attribute {AshPaperTrail.Test.Tenant, :parse_tenant, []}
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
  end
end
