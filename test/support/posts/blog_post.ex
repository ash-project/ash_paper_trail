defmodule AshPaperTrail.Test.Posts.BlogPost do
  @moduledoc """
  A blog_post is like a post but uses `only_when_changed? false`
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
    relationship_opts public?: true
    only_when_changed?(false)

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
    define :upsert
  end

  actions do
    default_accept :*
    defaults [:create, :read, :update, :destroy]

    create :upsert do
      upsert? true
      upsert_identity :unique_subject_per_tenant
      upsert_fields [:body, :tags, :author, :published, :secret]
      upsert_condition expr(body != ^atomic_ref(:body))
      return_skipped_upsert? true
    end

    update :publish do
      require_atomic? false
      accept []
      change set_attribute(:published, true)

      change after_transaction(fn _changeset, res, _ ->
               res
             end)
    end
  end

  multitenancy do
    strategy :attribute
    attribute :tenant
    parse_attribute {AshPaperTrail.Test.Tenant, :parse_tenant, []}
  end

  identities do
    identity :unique_subject_per_tenant, [:subject, :tenant],
      pre_check_with: AshPaperTrail.Test.Posts.Domain
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
