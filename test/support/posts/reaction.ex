# SPDX-FileCopyrightText: 2022 ash_paper_trail contributors <https://github.com/ash-project/ash_paper_trail/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshPaperTrail.Test.Posts.Reaction do
  @moduledoc """
  A FeatureVariant is possible value/setting for a Feature. There are multiple types of
  features (boolean, string, integer and object). Each type of Feature has a corresponding
  FeatureVariant.
  """

  use Ash.Type.NewType,
    subtype_of: :union,
    constraints: [
      storage: :type_and_value,
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
