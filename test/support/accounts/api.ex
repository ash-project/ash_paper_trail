defmodule AshPaperTrail.Test.Accounts.Api do
  @moduledoc false
  use Ash.Api, validate_config_inclusion?: false

  resources do
    resource AshPaperTrail.Test.Accounts.User
    resource AshPaperTrail.Test.Accounts.NewsFeed
  end
end
