defmodule AshPaperTrail.Dumpers.FullDiff do
  def build_changes(attributes, changeset) do
    Enum.reduce(attributes, %{}, &build_attribute_change(&1, changeset, &2))
  end

  defp build_attribute_change(%{type: {:array, _type}} = attribute, changeset, changes) do
    if changeset.action_type == :create do
      Map.put(
        changes,
        attribute.name,
        %{to: []}
      )
    else
      Map.put(
        changes,
        attribute.name,
        %{unchanged: []}
      )
    end
  end

  defp build_attribute_change(attribute, changeset, changes) do
    if Ash.Type.embedded_type?(attribute.type) do

      data = Ash.Changeset.get_data(changeset, attribute.name) |> dump_value(attribute)

      case Ash.Changeset.fetch_change(changeset, attribute.name) do
        {:ok, nil} ->
          Map.put(changes, attribute.name, build_map_changes(data, nil))

        {:ok, value} ->
          Map.put(
            changes,
            attribute.name,
            build_map_changes(data, dump_value(value, attribute))
          )

        :error ->
          if changeset.action_type == :create do
            Map.put(changes, attribute.name, %{to: data})
          else
            Map.put(changes, attribute.name, %{unchanged: data})
          end
      end
    else
      {data_present, data} =
        if changeset.action_type == :create do
          {false, nil}
        else
          {true, Ash.Changeset.get_data(changeset, attribute.name)}
        end

      case Ash.Changeset.fetch_change(changeset, attribute.name) do
        {:ok, value} ->
          Map.put(
            changes,
            attribute.name,
            dump_change_value(
              data_present,
              data,
              true,
              value
            )
          )

        :error ->
          Map.put(
            changes,
            attribute.name,
            dump_change_value(
              data_present,
              data,
              data_present,
              data
            )
          )
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
           dump_change_value(
             Map.has_key?(from_map, key),
             Map.get(from_map, key),
             Map.has_key?(to_map, key),
             Map.get(to_map, key)
           )}
  end

  defp dump_change_value(false, _from, _, to), do: %{to: to}
  defp dump_change_value(true, from, false, _to), do: %{from: from}
  defp dump_change_value(true, from, true, from), do: %{unchanged: from}
  defp dump_change_value(true, from, true, to), do: %{from: from, to: to}

  defp dump_value(nil, _attribute), do: nil

  defp dump_value(value, attribute) do
    {:ok, dumped_value} = Ash.Type.dump_to_embedded(attribute.type, value, [])
    dumped_value
  end
end
