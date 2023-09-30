defmodule AshPaperTrail.Dumpers.FullDiff do
  def build_changes(attributes, changeset) do
    Enum.reduce(attributes, %{}, &build_attribute_change(&1, changeset, &2))
  end

  defp build_attribute_change(attribute, %{action: %{type: :create}} = changeset, changes) do
    case Ash.Changeset.fetch_change(changeset, attribute.name) do
      {:ok, value} ->
        Map.put(changes, attribute.name, %{to: dump_value(value, attribute)})

      :error ->
        Map.put(changes, attribute.name, %{to: nil})
    end
  end

  defp build_attribute_change(attribute, changeset, changes) do
    dumped_data = Ash.Changeset.get_data(changeset, attribute.name) |> dump_value(attribute)

    if Ash.Type.embedded_type?(attribute.type) do
      case Ash.Changeset.fetch_change(changeset, attribute.name) do
        {:ok, value} ->
          Map.put(
            changes,
            attribute.name,
            build_map_changes(dumped_data, dump_value(value, attribute))
          )

        :error ->
          Map.put(changes, attribute.name, %{unchanged: dumped_data})
      end
    else
      case Ash.Changeset.fetch_change(changeset, attribute.name) do
        {:ok, value} ->
          Map.put(changes, attribute.name, %{
            from: dumped_data,
            to: dump_value(value, attribute)
          })

        :error ->
          Map.put(changes, attribute.name, %{unchanged: dumped_data})
      end
    end
  end

  defp build_map_changes(nil, value) do
    %{created: dump_map_changes(%{}, value)}
  end

  defp build_map_changes(data, nil) do
    %{destroyed: dump_map_changes(data, %{})}
  end

  defp build_map_changes(data, value) do
    %{update: dump_map_changes(data, value)}
  end

  defp dump_map_changes(%{} = from_map, %{} = to_map) do
    keys = Map.keys(from_map) ++ Map.keys(to_map)

    for key <- keys,
        into: %{},
        do:
          {key,
           dump_map_change_value(
             Map.has_key?(from_map, key),
             Map.get(from_map, key),
             Map.has_key?(to_map, key),
             Map.get(to_map, key)
           )}
  end

  defp dump_map_change_value(false, _from, true, to), do: %{to: to}
  defp dump_map_change_value(true, from, false, _to), do: %{from: from}
  defp dump_map_change_value(true, from, true, from), do: %{unchanged: from}
  defp dump_map_change_value(true, from, true, to), do: %{from: from, to: to}

  defp dump_value(nil, _attribute), do: nil

  defp dump_value(value, attribute) do
    {:ok, dumped_value} = Ash.Type.dump_to_embedded(attribute.type, value, [])
    dumped_value
  end
end
