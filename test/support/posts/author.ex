defmodule AshPaperTrail.Test.Posts.Author do
  @moduledoc false
  use Ash.Resource,
    data_layer: :embedded,
    validate_api_inclusion?: false

  attributes do
    attribute :first_name, :string
    attribute :last_name, :string
  end
end
