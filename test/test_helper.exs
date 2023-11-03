ExUnit.start()

defmodule TestHelper do
  def last_version_changes(api, version_resource) do
    api.read!(version_resource)
    |> Enum.sort_by(& &1.version_inserted_at)
    |> List.last()
    |> Map.get(:changes)
  end
end
