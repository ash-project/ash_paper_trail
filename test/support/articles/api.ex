defmodule AshPaperTrail.Test.Articles.Api do
  use Ash.Api, extensions: [AshPaperTrail.Api], validate_config_inclusion?: false

  resources do
    resource AshPaperTrail.Test.Articles.Article
  end
end
