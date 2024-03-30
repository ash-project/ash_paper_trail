ExUnit.start()

defmodule TestHelper do
  def last_version_changes(domain, version_resource) do
    Ash.read!(version_resource, domain: domain)
    |> Enum.sort_by(& &1.version_inserted_at)
    |> List.last()
    |> Map.get(:changes)
  end
end
