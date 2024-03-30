defmodule AshPaperTrail.Test.Articles.Domain do
  @moduledoc false
  use Ash.Domain, extensions: [AshPaperTrail.Domain], validate_config_inclusion?: false

  resources do
    resource AshPaperTrail.Test.Articles.Article
  end
end
