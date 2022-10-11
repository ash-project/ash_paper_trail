defmodule AshPaperTrail.Test.Api do
  use Ash.Api

  resources do
    registry AshPaperTrail.Test.Registry
  end
end
