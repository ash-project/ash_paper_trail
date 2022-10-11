defmodule AshPaperTrail.Test.Registry do
  use Ash.Registry,
    extensions: [Ash.Registry.ResourceValidations, AshPaperTrail.Registry]

  entries do
    entry AshPaperTrail.Test.Post
  end
end
