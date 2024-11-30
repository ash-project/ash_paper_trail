defmodule AshPaperTrail.Test.Posts.Domain do
  @moduledoc false
  use Ash.Domain, extensions: [AshPaperTrail.Domain], validate_config_inclusion?: false

  resources do
    resource AshPaperTrail.Test.Posts.Post
    resource AshPaperTrail.Test.Posts.Post.Version
    resource AshPaperTrail.Test.Posts.FullDiffPost
    resource AshPaperTrail.Test.Posts.FullDiffPost.Version
    resource AshPaperTrail.Test.Posts.StoreInputsPost
    resource AshPaperTrail.Test.Posts.StoreInputsPost.Version
  end
end
