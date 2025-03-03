defmodule AshPaperTrail.Test.Posts.StoreInputsPost do
  @moduledoc """
    A page is like a post but uses the change_tracking_mode :changes_only
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
    attributes_as_attributes [:subject, :body, :tenant, :secret]
    ignore_attributes [:inserted_at]
    change_tracking_mode :changes_only
    store_action_name? true
    store_action_inputs? true
    relationship_opts public?: true

    belongs_to_actor :user, AshPaperTrail.Test.Accounts.User,
      domain: AshPaperTrail.Test.Accounts.Domain

    belongs_to_actor :news_feed, AshPaperTrail.Test.Accounts.NewsFeed,
      domain: AshPaperTrail.Test.Accounts.Domain
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
    defaults [:read, :destroy]

    create :create do
      accept [:id, :subject, :body, :secret, :author, :tags, :published]
      argument :req_arg, :string, allow_nil?: false
      argument :opt_arg, :string, allow_nil?: true
      argument :req_sensitive_arg, :string, sensitive?: true, allow_nil?: false
      argument :opt_sensitive_arg, :string, sensitive?: true, allow_nil?: true
    end

    update :update do
      require_atomic? false
      accept [:subject, :body, :secret, :author, :tags, :published]
      argument :req_arg, :string, allow_nil?: false
      argument :opt_arg, :string, allow_nil?: true
      argument :req_sensitive_arg, :string, sensitive?: true, allow_nil?: false
      argument :opt_sensitive_arg, :string, sensitive?: true, allow_nil?: true
    end

    update :publish do
      require_atomic? false
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
    uuid_primary_key :id, writable?: true

    attribute :tenant, :string do
      allow_nil? false
    end

    attribute :subject, :string do
      public? true
      allow_nil? false
    end

    attribute :body, :string do
      public? true
      allow_nil? false
    end

    attribute :secret, :string, sensitive?: true

    attribute :author, AshPaperTrail.Test.Posts.Author do
      public? true
      allow_nil? true
    end

    attribute :tags, {:array, AshPaperTrail.Test.Posts.Tag} do
      public? true
      allow_nil? false
      default []
    end

    attribute :published, :boolean do
      public? true
      allow_nil? false
      default false
    end

    create_timestamp :inserted_at
  end
end
