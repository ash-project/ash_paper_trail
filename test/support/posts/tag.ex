defmodule AshPaperTrail.Test.Posts.Tag do
  @moduledoc false
  use Ash.Resource,
    data_layer: :embedded,
    validate_api_inclusion?: false

  attributes do
    uuid_primary_key :id

    attribute :tag, :string
  end
end
