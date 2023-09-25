defmodule AshPaperTrail.Test.Posts.Api do
  use Ash.Api, validate_config_inclusion?: false

  resources do
    registry AshPaperTrail.Test.Posts.Registry
  end
end
