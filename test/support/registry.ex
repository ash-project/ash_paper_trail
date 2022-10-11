defmodule AshPaperTrail.Test.Registry do
  use Ash.Registry

  entries do
    entry AshPaperTrail.Test.Post
  end
end
