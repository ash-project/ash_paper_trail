defmodule AshPaperTrail.Test.Articles.Article do
  @moduledoc false
  use Ash.Resource,
    domain: AshPaperTrail.Test.Articles.Domain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshPaperTrail.Resource],
    validate_domain_inclusion?: false

  ets do
    private? true
  end

  paper_trail do
    primary_key_type :integer
    attributes_as_attributes [:subject, :body]
    change_tracking_mode :snapshot
  end

  code_interface do
    define :create, args: [:subject, :body]
    define :read
    define :update
    define :destroy
  end

  actions do
    default_accept [:*, :body]
    defaults [:create, :read, :update, :destroy]
  end

  attributes do
    uuid_primary_key :id, writable?: true

    attribute :subject, :string do
      public? true
      allow_nil? false
    end

    attribute :body, :string do
      public? false
      allow_nil? false
    end
  end
end
