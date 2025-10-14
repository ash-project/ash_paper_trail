# SPDX-FileCopyrightText: 2022 ash_paper_trail contributors <https://github.com/ash-project/ash_paper_trail/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshPaperTrail.Test.Posts.Domain do
  @moduledoc false
  use Ash.Domain, extensions: [AshPaperTrail.Domain], validate_config_inclusion?: false

  resources do
    resource AshPaperTrail.Test.Posts.Post
    resource AshPaperTrail.Test.Posts.BlogPost
    resource AshPaperTrail.Test.Posts.BlogPost.Version
    resource AshPaperTrail.Test.Posts.Post.Version
    resource AshPaperTrail.Test.Posts.FullDiffPost
    resource AshPaperTrail.Test.Posts.FullDiffPost.Version
    resource AshPaperTrail.Test.Posts.StoreInputsPost
    resource AshPaperTrail.Test.Posts.StoreInputsPost.Version
    resource AshPaperTrail.Test.Posts.NoDestroyVersionPost
    resource AshPaperTrail.Test.Posts.NoDestroyVersionPost.Version
    resource AshPaperTrail.Test.Posts.UpsertPost
    resource AshPaperTrail.Test.Posts.UpsertPost.Version
  end
end
