defmodule AshPaperTrail.Test.Articles.Api do
  use Ash.Api, validate_config_inclusion?: false

  resources do
    registry AshPaperTrail.Test.Articles.Registry
  end
end
