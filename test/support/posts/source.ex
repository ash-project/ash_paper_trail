defmodule AshPaperTrail.Test.Posts.Source do
  @moduledoc """
  A FeatureVariant is possible value/setting for a Feature. There are multiple types of
  features (boolean, string, integer and object). Each type of Feature has a corresponding
  FeatureVariant.
  """

  use Ash.Type.NewType,
    subtype_of: :union,
    constraints: [
      types: [
        blog: [
          tag: :type,
          tag_value: :blog,
          type: AshPaperTrail.Test.Posts.SourceBlog
        ],
        book: [
          tag: :type,
          tag_value: :book,
          type: AshPaperTrail.Test.Posts.SourceBook
        ]
      ]
    ]
end
