# SPDX-FileCopyrightText: 2022 ash_paper_trail contributors <https://github.com/ash-project/ash_paper_trail/graphs.contributors>
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
