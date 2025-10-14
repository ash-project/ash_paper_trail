# SPDX-FileCopyrightText: 2022 ash_paper_trail contributors <https://github.com/ash-project/ash_paper_trail/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshPaperTrail.Test.Posts.Source do
  @moduledoc false

  use Ash.Type.NewType,
    subtype_of: :union,
    constraints: [
      storage: :type_and_value,
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
        ],
        link: [
          type: :string
        ]
      ]
    ]
end
