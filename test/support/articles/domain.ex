defmodule AshPaperTrail.Test.Articles.Domain do
  @moduledoc false
  use Ash.Domain, extensions: [AshPaperTrail.Domain], validate_config_inclusion?: false

  authorization do
    authorize(:always)
  end

  resources do
    resource AshPaperTrail.Test.Articles.Article
  end
end
