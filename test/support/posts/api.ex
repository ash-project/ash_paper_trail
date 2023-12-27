defmodule AshPaperTrail.Test.Posts.Api do
  @moduledoc false
  use Ash.Api, extensions: [AshPaperTrail.Api], validate_config_inclusion?: false

  resources do
    resource AshPaperTrail.Test.Posts.Post
    resource AshPaperTrail.Test.Posts.Post.Version
    resource AshPaperTrail.Test.Posts.FullDiffPost
    resource AshPaperTrail.Test.Posts.FullDiffPost.Version
  end
end
