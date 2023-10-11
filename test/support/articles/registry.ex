defmodule AshPaperTrail.Test.Articles.Registry do
  @moduledoc false
  use Ash.Registry,
    extensions: [Ash.Registry.ResourceValidations, AshPaperTrail.Registry]

  entries do
    entry AshPaperTrail.Test.Articles.Article
  end
end
