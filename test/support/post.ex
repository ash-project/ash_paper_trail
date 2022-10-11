defmodule AshPaperTrail.Test.Post do
  use Ash.Resource,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshPaperTrail.Resource]

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
