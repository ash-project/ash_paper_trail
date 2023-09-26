defmodule AshPaperTrail.Test.Posts.Registry do
  use Ash.Registry,
    extensions: [Ash.Registry.ResourceValidations, AshPaperTrail.Registry]

  entries do
    entry AshPaperTrail.Test.Posts.Post
  end
end
