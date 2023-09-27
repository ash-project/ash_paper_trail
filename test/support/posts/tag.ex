defmodule AshPaperTrail.Test.Posts.Tag do
  use Ash.Resource,
    data_layer: :embedded,
    validate_api_inclusion?: false

  attributes do
    attribute :tag, :string
  end
end
