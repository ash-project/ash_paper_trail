# SPDX-FileCopyrightText: 2020 Zach Daniel
#
# SPDX-License-Identifier: MIT

defmodule AshPaperTrail.Test.Accounts.Domain do
  @moduledoc false
  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource AshPaperTrail.Test.Accounts.User
    resource AshPaperTrail.Test.Accounts.User.Version
    resource AshPaperTrail.Test.Accounts.NewsFeed
  end
end
