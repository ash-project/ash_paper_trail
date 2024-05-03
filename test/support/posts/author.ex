defmodule AshPaperTrail.Test.Posts.Author do
  @moduledoc false
  use Ash.Resource,
    data_layer: :embedded,
    validate_domain_inclusion?: false

  attributes do
    uuid_primary_key :id, writable?: true
    attribute :first_name, :string, public?: true
    attribute :last_name, :string, public?: true
  end
end
