# SPDX-FileCopyrightText: 2022 ash_paper_trail contributors <https://github.com/ash-project/ash_paper_trail/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshPaperTrail.Test.Articles.Domain do
  @moduledoc false
  use Ash.Domain, extensions: [AshPaperTrail.Domain], validate_config_inclusion?: false

  paper_trail do
    include_versions?(true)
  end

  authorization do
    authorize(:always)
  end

  resources do
    resource AshPaperTrail.Test.Articles.Article
  end
end
