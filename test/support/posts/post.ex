defmodule AshPaperTrail.Test.Posts.Post do
  use Ash.Resource,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshPaperTrail.Resource],
    validate_api_inclusion?: false

  ets do
    private? true
  end

  paper_trail do
    attributes_as_attributes [:subject, :body]
  end

  code_interface do
    define_for AshPaperTrail.Test.Posts.Api

    define :create, args: [:subject, :body]
    define :read
    define :update
    define :destroy
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end

  attributes do
    uuid_primary_key :id

    attribute :subject, :string do
      allow_nil? false
    end

    attribute :body, :string do
      allow_nil? false
    end
  end
end
