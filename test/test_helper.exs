# SPDX-FileCopyrightText: 2022 ash_paper_trail contributors <https://github.com/ash-project/ash_paper_trail/graphs.contributors>
#
# SPDX-License-Identifier: MIT

ExUnit.start()

defmodule TestHelper do
  def last_version_changes(domain, version_resource) do
    version_resource
    |> Ash.read!(domain: domain)
    |> sort_versions()
    |> List.last()
    |> Map.get(:changes)
  end

  def sort_versions(versions) do
    Enum.sort_by(versions, fn v ->
      {
        Map.get(v, :version_source_id),
        Map.get(v, :version_action_type),
        Map.get(v, :version_action_name),
        Map.get(v, :version_inserted_at)
      }
    end)
  end
end
