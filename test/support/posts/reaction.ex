defmodule AshPaperTrail.Test.Posts.Reaction do
  @moduledoc """
  A FeatureVariant is possible value/setting for a Feature. There are multiple types of
  features (boolean, string, integer and object). Each type of Feature has a corresponding
  FeatureVariant.
  """
  alias AshPaperTrail.Test.Posts

  use Ash.Type.NewType,
    subtype_of: :union,
    constraints: [
      types: [
        score: [
          type: :integer
        ],
        comment: [
          type: :string
        ]
      ]
    ]
end
