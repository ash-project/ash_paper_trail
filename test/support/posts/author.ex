defmodule AshPaperTrail.Test.Posts.Author do
  @moduledoc false
  use Ash.Resource,
    data_layer: :embedded,
    validate_domain_inclusion?: false

  attributes do
    attribute :first_name, :string, public?: true
    attribute :last_name, :string, public?: true
  end
end
