
defmodule AshPaperTrail.Dumpers.FullDiff do
  def build_changes(attributes, changeset) do
    Enum.reduce(attributes, %{}, &build_attribute_change(&1, changeset, &2))
  end

  defp build_attribute_change(%{type: {:array, _type}} = attribute, changeset, changes) do
    if Ash.Type.embedded_type?(attribute.type) do
      build_attribute_change(:embedded_array, attribute, changeset, changes)
    else
      build_attribute_change(:simple, attribute, changeset, changes)
    end
  end

  defp build_attribute_change(attribute, changeset, changes) do
    if Ash.Type.embedded_type?(attribute.type) do
      build_attribute_change(:embedded, attribute, changeset, changes)
    else
      build_attribute_change(:simple, attribute, changeset, changes)
    end
  end

  defp build_attribute_change(:embedded_array, attribute, changeset, changes) do
    # Get the primary keys
    {:array, resource} = attribute.type
    primary_keys = Ash.Resource.Info.primary_key(resource)

    # Get the datas (changing from)
    {uniq_keys, datas, data_indexes} = Ash.Changeset.get_data(changeset, attribute.name) 
    |> dump_value(attribute)
    |> List.wrap() 
    |> Enum.with_index(& {&2, &1})
    |> Enum.reduce({MapSet.new(), %{}, %{}}, fn {index, data}, {uniq_keys, datas, data_indexes} ->
      keys = map_get_keys(data, primary_keys)
      {MapSet.put(uniq_keys, keys), Map.put(datas, keys, data), Map.put(data_indexes, keys, index)}
    end)

    # Get the values (changing to)
    {uniq_keys, values, value_indexes} = case Ash.Changeset.fetch_change(changeset, attribute.name) do
     {:ok, values} -> values
     :error -> []
    end 
    |> dump_value(attribute)
    |> Enum.with_index(& {&2, &1})
    |> Enum.reduce({uniq_keys, %{}, %{}}, fn {index, value}, {uniq_keys, values, value_indexes} ->
      keys = map_get_keys(value, primary_keys)
      {MapSet.put(uniq_keys, keys), Map.put(values, keys, value), Map.put(value_indexes, keys, index)}
    end)    

    # Build a change for each id
    {changed?, embedded_changes} = Enum.reduce(uniq_keys, {false, []}, fn key, {changed?, embedded_changes} -> 
      data = Map.get(datas, key)
      value = Map.get(values, key)

      index_change = dump_change_value(
            Map.has_key?(data_indexes, key),
            Map.get(data_indexes, key),
            Map.has_key?(value_indexes, key),
            Map.get(value_indexes, key)
          )

      case build_map_changes(data, value) do 
        %{unchanged: _unchanged} = change ->
          change = Map.put(change, :index, index_change)
          {changed?, [change | embedded_changes ]}

        %{} = change ->
          change = Map.put(change, :index, index_change)
          {true, [change | embedded_changes]}
      end
    end)

    # Sort them by [current_index, 1] if present, [datas_index, 0] previous index (if removed)
    embedded_changes = Enum.sort_by(embedded_changes, fn change -> 
      case change do
        %{destroyed: _embedded, index: %{from: i}} -> [i, 0]
        %{index: %{to: i}} -> [i, 1]
      end
    end)

    if ((changeset.action_type == :create) || changed?) do
      Map.put(
        changes,
        attribute.name,
        %{to: embedded_changes}
      )
    else
      Map.put(
        changes,
        attribute.name,
        %{unchanged: embedded_changes}
      )
    end
  end

  defp build_attribute_change(:embedded, attribute, changeset, changes) do
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
  end

  defp build_attribute_change(:simple, attribute, changeset, changes) do
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

  defp build_map_changes(nil, value) do
    %{created: dump_map_changes(%{}, value)}
  end

  defp build_map_changes(data, nil) do
    %{destroyed: dump_map_changes(data, %{})}
  end

  defp build_map_changes(data, data) do
    %{unchanged: dump_map_changes(data, data)}
  end

  defp build_map_changes(data, value) do
    %{updated: dump_map_changes(data, value)}
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

  defp map_get_keys(resource, keys) do
    Enum.map(keys, &Map.get(resource, &1))
  end
end
