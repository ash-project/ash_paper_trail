defmodule AshPaperTrail.Test.Articles.Article do
  use Ash.Resource,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshPaperTrail.Resource],
    validate_api_inclusion?: false

  ets do
    private? true
  end

  paper_trail do
    attributes_as_attributes [:subject, :body, :tenant]
  end

  code_interface do
    define_for AshPaperTrail.Test.Articles.Api

    define :create, args: [:subject, :body]
    define :read
    define :update
    define :destroy
  end

  multitenancy do
    strategy :attribute
    attribute :tenant
    parse_attribute {AshPaperTrail.Test.Tenant, :parse_tenant, []}
  end

  actions do
    defaults [:create, :read, :update, :destroy]
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
  end
end
