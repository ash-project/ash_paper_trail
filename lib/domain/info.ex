# SPDX-FileCopyrightText: 2022 ash_paper_trail contributors <https://github.com/ash-project/ash_paper_trail/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshPaperTrail.Domain.Info do
  @moduledoc "Introspection helpers for `AshPaperTrail.Domain`"

  def include_versions?(domain) do
    Spark.Dsl.Extension.get_opt(domain, [:paper_trail], :include_versions?, false)
  end
end
