defmodule AshPaperTrail.Test.Posts.SourceBlog do
  use Ash.Resource,
    data_layer: :embedded,
    validate_api_inclusion?: false

  attributes do
    uuid_primary_key :id

    attribute :type, :string
    attribute :name, :string
    attribute :url, :string
  end
end
