# SPDX-FileCopyrightText: 2020 Zach Daniel
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
