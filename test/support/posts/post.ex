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
  end

  code_interface do
    define_for AshPaperTrail.Test.Posts.Api

    define :create
    define :read
    define :update
    define :destroy
  end

  actions do
    defaults [:create, :read, :update, :destroy]
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
  end
end
