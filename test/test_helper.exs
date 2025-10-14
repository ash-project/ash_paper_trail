# SPDX-FileCopyrightText: 2022 ash_paper_trail contributors <https://github.com/ash-project/ash_paper_trail/graphs.contributors>
#
# SPDX-License-Identifier: MIT

ExUnit.start()

defmodule TestHelper do
  def last_version_changes(domain, version_resource) do
    Ash.read!(version_resource, domain: domain)
    |> Enum.sort_by(& &1.version_inserted_at)
    |> List.last()
    |> Map.get(:changes)
  end
end
