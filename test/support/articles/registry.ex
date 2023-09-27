defmodule AshPaperTrail.Test.Articles.Registry do
  use Ash.Registry,
    extensions: [Ash.Registry.ResourceValidations, AshPaperTrail.Registry]

  entries do
    entry AshPaperTrail.Test.Articles.Article
  end
end
