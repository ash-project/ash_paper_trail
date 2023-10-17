defmodule AshPaperTrail.Dumpers.FullDiff do
  # def build_changes(attributes, changeset) do
  #   Enum.reduce(attributes, %{}, &build_attribute_change(&1, changeset, &2))
  # end

  def build_changes(attributes, changeset) do
    Enum.reduce(attributes, %{}, fn attribute, changes ->
      Map.put(
        changes,
        attribute.name,
        build_attribute_change(attribute, changeset)
      )
    end)
  end

  def build_attribute_change(%{type: {:array, type}} = attribute, changeset) do
    # a composite array is a union or embedded type which we treat as individual values
    if is_union?(type) || is_embedded?(type) do
      build_composite_array_change(attribute, changeset)

      # a non-composite array is treated as a single value
    else
      build_simple_change(attribute, changeset)
    end
  end

  def build_attribute_change(attribute, changeset) do
    # embedded types are created, updated, destroyed, and have their individual attributes tracked
    if is_embedded?(attribute.type) do
      build_embedded_change(attribute, changeset)

      # non-embedded types are treated as a single value
    else
      build_simple_change(attribute, changeset)
    end
  end

  # A simple attribute change will be represented as a map:
  #
  #   %{ to: value }
  #   %{ from: value, to: value }
  #   %{ unchange: value }
  #
  # if the attribute is a union, then there will also be a type key
  def build_simple_change(attribute, changeset) do
    {data_present, dumped_data} =
      if changeset.action_type == :create do
        {false, nil}
      else
        {true, Ash.Changeset.get_data(changeset, attribute.name) |> dump_value(attribute)}
      end

    case Ash.Changeset.fetch_change(changeset, attribute.name) do
      {:ok, value} ->
        build_simple_change_map(
          data_present,
          dumped_data,
          true,
          dump_value(value, attribute)
        )

      :error ->
        build_simple_change_map(
          data_present,
          dumped_data,
          data_present,
          dumped_data
        )
    end
  end

  # A simple attribute change will be represented as a map:
  #
  #   %{ created: %{ ...attrs... } }
  #   %{ updated: %{ ...attrs... } }
  #   %{ unchanged: %{ ...attrs... } }
  #   %{ destroyed: %{ ...attrs... } }
  #
  # if the attribute is a union, then there will also be a type key.
  # The attrs will be the attributes of the embedded resource treated as simple changes.
  def build_embedded_change(attribute, changeset) do
    dumped_data = Ash.Changeset.get_data(changeset, attribute.name) |> dump_value(attribute)

    case Ash.Changeset.fetch_change(changeset, attribute.name) do
      {:ok, nil} ->
        build_embedded_changes(dumped_data, nil)

      {:ok, value} ->
        build_embedded_changes(dumped_data, dump_value(value, attribute))

      :error ->
        if changeset.action_type == :create do
          %{to: nil}
        else
          build_embedded_changes(dumped_data, dumped_data)
        end
    end
  end

  defp build_embedded_changes(nil, nil), do: %{unchanged: nil}

  defp build_embedded_changes(nil, %{} = value),
    do: %{created: build_embedded_attribute_changes(%{}, value)}

  defp build_embedded_changes(%{} = data, nil),
    do: %{destroyed: build_embedded_attribute_changes(data, %{})}

  defp build_embedded_changes(%{} = data, data),
    do: %{unchanged: build_embedded_attribute_changes(data, data)}

  defp build_embedded_changes(%{} = data, %{} = value),
    do: %{updated: build_embedded_attribute_changes(data, value)}

  defp build_embedded_attribute_changes(%{} = from_map, %{} = to_map) do
    keys = Map.keys(from_map) ++ Map.keys(to_map)

    for key <- keys,
        into: %{},
        do:
          {key,
           build_simple_change_map(
             Map.has_key?(from_map, key),
             Map.get(from_map, key),
             Map.has_key?(to_map, key),
             Map.get(to_map, key)
           )}
  end

  # A composite attribute change will be represented as a map:
  #
  #   %{ to: [ %{}, %{}, %{}] }
  #   %{ unchanged: [ %{}, %{}, %{}] }
  #
  # Each element of the array will be represent as a simple change or an embedded change.
  # It will incude a union key if applicable.  Embedded resources with primary_keys will also
  # include an `index` key set to `%{from: x, to: y}` or `%{to: x}` or `%{ucnhanged: x}`.
  def build_composite_array_change(attribute, changeset) do
    data = Ash.Changeset.get_data(changeset, attribute.name)
    dumped_data = dump_value(data, attribute)

    {data_indexes, data_lookup, data_ids} =
      Enum.zip(List.wrap(data), List.wrap(dumped_data))
      |> Enum.with_index(fn {data, dumped_data}, index -> {index, data, dumped_data} end)
      |> Enum.reduce({%{}, %{}, MapSet.new()}, fn {index, data, dumped_data}, {data_indexes, data_lookup, data_ids} ->
        primary_keys = primary_keys(data)
        keys = map_get_keys(data, primary_keys)

        {
          Map.put(data_indexes, keys, index),
          Map.put(data_lookup, keys, dumped_data),
          MapSet.put(data_ids, keys)
        }
      end)

    values =
      case Ash.Changeset.fetch_change(changeset, attribute.name) do
        {:ok, values} -> values
        :error -> []
      end

    {dumped_values, dumped_ids} =
      Enum.zip(values, dump_value(values, attribute))
      |> Enum.with_index(fn {value, dumped_value}, index -> {index, value, dumped_value} end)
      |> Enum.reduce({[], MapSet.new()}, fn {to_index, value, dumped_value}, {dumped_values, dumped_ids} ->
        case primary_keys(value) do
          [] ->
            %{created: build_embedded_attribute_changes(%{}, dumped_value), no_primary_key: true }

          primary_keys ->
            keys = map_get_keys(value, primary_keys)

            dumped_data = Map.get(data_lookup, keys)

            change = build_embedded_changes(dumped_data, dumped_value)
            # change = %{created: build_embedded_attribute_changes(dumped_data, dumped_value) }

            index_change = Map.get(data_indexes, keys) |> build_index_change(to_index)

            {
              [Map.put(change, :index, index_change) | dumped_values],
              MapSet.put(dumped_ids, keys)
            }
        end
      end)

    dumped_values =
      MapSet.difference(data_ids, dumped_ids)
      |> Enum.reduce(dumped_values, fn keys, dumped_values ->
        dumped_data = Map.get(data_lookup, keys)

        change = build_embedded_changes(dumped_data, nil)

        index_change = Map.get(data_indexes, keys) |> build_index_change(nil)

        [Map.put(change, :index, index_change) | dumped_values]
      end)

    if changeset.action_type == :create do
      %{to: sort_composite_array_changes(dumped_values)}
    else
      build_composite_array_changes(dumped_data, dumped_values)
    end
  end

  def build_composite_array_changes(dumped_values, dumped_values), do: %{unchanged: dumped_values}
  def build_composite_array_changes(nil, []), do: %{unchanged: []}
  def build_composite_array_changes(_dumped_data, dumped_values) do
    %{to: sort_composite_array_changes(dumped_values)}
  end

  def build_index_change(nil, to), do: %{to: to}
  def build_index_change(from, from), do: %{unchanged: from}
  def build_index_change(from, to), do: %{from: from, to: to}

  def sort_composite_array_changes(dumped_values) do
    Enum.sort_by(dumped_values, fn change ->
      case change do
        %{destroyed: _embedded, index: %{from: i}} -> [i, 0]
        %{index: %{to: i}} -> [i, 1]
        %{index: %{unchanged: i}} -> [i, 1]
      end
    end)
  end

  # defp build_attribute_change(%{type: {:array, type}} = attribute, changeset, changes) do
  #   cond do
  #     Ash.Type.embedded_type?(attribute.type) ->
  #       build_attribute_change(:embedded_array, attribute, changeset, changes)

  #     is_union?(type) ->
  #       build_attribute_change(:embedded_union, attribute, changeset, changes)

  #     true ->
  #       build_attribute_change(:simple, attribute, changeset, changes)
  #   end
  # end

  # defp build_attribute_change(attribute, changeset, changes) do
  #   if Ash.Type.embedded_type?(attribute.type) do
  #     build_attribute_change(:embedded, attribute, changeset, changes)
  #   else
  #     build_attribute_change(:simple, attribute, changeset, changes)
  #   end
  # end

  # defp build_attribute_change(:embedded_union, attribute, changeset, changes) do
  #   # Get the datas (changing from)
  #   {uniq_keys, datas, data_indexes} =
  #     Ash.Changeset.get_data(changeset, attribute.name)
  #     |> dump_value(attribute)
  #     |> List.wrap()
  #     |> Enum.with_index(&{&2, &1})
  #     |> Enum.reduce({MapSet.new(), %{}, %{}}, fn {index, data},
  #                                                 {uniq_keys, datas, data_indexes} ->
  #       primary_keys = Ash.Resource.Info.primary_key(data)
  #       keys = map_get_keys(data, primary_keys)

  #       {MapSet.put(uniq_keys, keys), Map.put(datas, keys, data),
  #        Map.put(data_indexes, keys, index)}
  #     end)

  #     raw_values = case Ash.Changeset.fetch_change(changeset, attribute.name) do
  #       {:ok, values} -> values
  #       :error -> []
  #     end

  #     {:ok, dumped_values} = Ash.Type.dump_to_embedded(attribute.type, raw_values, attribute.constraints)

  #   # Get the values (changing to)
  #   {uniq_keys, values, value_indexes} =
  #     dumped_values
  #     |> Enum.with_index(&{&2, &1})
  #     |> Enum.reduce({uniq_keys, %{}, %{}}, fn {index, value},
  #                                              {uniq_keys, values, value_indexes} ->

  #     #   primary_keys = Ash.Resource.Info.primary_key(value)
  #     #   keys = map_get_keys(value, primary_keys)
  #       keys = [value]

  #       {MapSet.put(uniq_keys, keys), Map.put(values, keys, value),
  #        Map.put(value_indexes, keys, index)}
  #     end) |> IO.inspect(label: "values")

  #   # Build a change for each id
  #   {changed?, embedded_changes} =
  #     Enum.reduce(uniq_keys, {false, []}, fn key, {changed?, embedded_changes} ->
  #       data = Map.get(datas, key) |> IO.inspect(label: "data")
  #       value = Map.get(values, key) |> IO.inspect(label: "value")

  #       index_change =
  #         dump_change_value(
  #           Map.has_key?(data_indexes, key),
  #           Map.get(data_indexes, key),
  #           Map.has_key?(value_indexes, key),
  #           Map.get(value_indexes, key)
  #         ) |> IO.inspect(label: "index_change")

  #         data["value"] |> IO.inspect(label: "data value")
  #         value["value"] |> IO.inspect(label: "value value")

  #       case build_map_changes(data, value) do
  #         %{unchanged: _unchanged} = change ->
  #           change = Map.put(change, :index, index_change)
  #           {changed?, [change | embedded_changes]}

  #         %{} = change ->
  #           change = Map.put(change, :index, index_change)
  #           {true, [change | embedded_changes]}
  #       end
  #     end) |> IO.inspect(label: "changes")

  #       # Sort them by [current_index, 1] if present, [datas_index, 0] previous index (if removed)
  #       embedded_changes =
  #         Enum.sort_by(embedded_changes, fn change ->
  #           case change do
  #             %{destroyed: _embedded, index: %{from: i}} -> [i, 0]
  #             %{index: %{to: i}} -> [i, 1]
  #             %{index: %{unchanged: i}} -> [i, 1]
  #           end
  #         end)

  #       if changeset.action_type == :create || changed? do
  #         Map.put(
  #           changes,
  #           attribute.name,
  #           %{to: embedded_changes}
  #         )
  #       else
  #         Map.put(
  #           changes,
  #           attribute.name,
  #           %{unchanged: embedded_changes}
  #         )
  #       end
  # end

  # defp build_attribute_change(:embedded_array, attribute, changeset, changes) do
  #   # Get the primary keys
  #   {:array, resource} = attribute.type
  #   primary_keys = Ash.Resource.Info.primary_key(resource)

  #   # Get the datas (changing from)
  #   {uniq_keys, datas, data_indexes} =
  #     Ash.Changeset.get_data(changeset, attribute.name)
  #     |> dump_value(attribute)
  #     |> List.wrap()
  #     |> Enum.with_index(&{&2, &1})
  #     |> Enum.reduce({MapSet.new(), %{}, %{}}, fn {index, data},
  #                                                 {uniq_keys, datas, data_indexes} ->
  #       keys = map_get_keys(data, primary_keys)

  #       {MapSet.put(uniq_keys, keys), Map.put(datas, keys, data),
  #        Map.put(data_indexes, keys, index)}
  #     end)

  #   # Get the values (changing to)
  #   {uniq_keys, values, value_indexes} =
  #     case Ash.Changeset.fetch_change(changeset, attribute.name) do
  #       {:ok, values} -> values
  #       :error -> []
  #     end
  #     |> dump_value(attribute)
  #     |> Enum.with_index(&{&2, &1})
  #     |> Enum.reduce({uniq_keys, %{}, %{}}, fn {index, value},
  #                                              {uniq_keys, values, value_indexes} ->
  #       keys = map_get_keys(value, primary_keys)

  #       {MapSet.put(uniq_keys, keys), Map.put(values, keys, value),
  #        Map.put(value_indexes, keys, index)}
  #     end)

  #   # Build a change for each id
  #   {changed?, embedded_changes} =
  #     Enum.reduce(uniq_keys, {false, []}, fn key, {changed?, embedded_changes} ->
  #       data = Map.get(datas, key)
  #       value = Map.get(values, key)

  #       index_change =
  #         dump_change_value(
  #           Map.has_key?(data_indexes, key),
  #           Map.get(data_indexes, key),
  #           Map.has_key?(value_indexes, key),
  #           Map.get(value_indexes, key)
  #         )

  #       case build_map_changes(data, value) do
  #         %{unchanged: _unchanged} = change ->
  #           change = Map.put(change, :index, index_change)
  #           {changed?, [change | embedded_changes]}

  #         %{} = change ->
  #           change = Map.put(change, :index, index_change)
  #           {true, [change | embedded_changes]}
  #       end
  #     end)

  #   # Sort them by [current_index, 1] if present, [datas_index, 0] previous index (if removed)
  #   embedded_changes =
  #     Enum.sort_by(embedded_changes, fn change ->
  #       case change do
  #         %{destroyed: _embedded, index: %{from: i}} -> [i, 0]
  #         %{index: %{to: i}} -> [i, 1]
  #         %{index: %{unchanged: i}} -> [i, 1]
  #       end
  #     end)

  #   if changeset.action_type == :create || changed? do
  #     Map.put(
  #       changes,
  #       attribute.name,
  #       %{to: embedded_changes}
  #     )
  #   else
  #     Map.put(
  #       changes,
  #       attribute.name,
  #       %{unchanged: embedded_changes}
  #     )
  #   end
  # end

  # defp build_attribute_change(:union_array, attribute, changeset, changes) do
  #   {data_present, datas} =
  #     if changeset.action_type == :create do
  #       {false, nil}
  #     else
  #       datas =
  #         Ash.Changeset.get_data(changeset, attribute.name)
  #         |> List.wrap()
  #         |> Enum.map(fn data -> dump_change_value(true, data, false, nil) end)

  #       {true, datas}
  #     end

  #   {value_present, values} =
  #     case Ash.Changeset.fetch_change(changeset, attribute.name) do
  #       {:ok, values} ->
  #         values =
  #           List.wrap(values)
  #           |> Enum.map(fn value -> dump_change_value(false, nil, true, value) end)

  #         {true, values}

  #       :error ->
  #         {false, nil}
  #     end

  #   Map.put(
  #     changes,
  #     attribute.name,
  #     dump_change_value(
  #       data_present,
  #       datas,
  #       value_present,
  #       values
  #     )
  #   )
  # end

  # defp dump_map_changes(%{} = from_map, %{} = to_map) do
  #   keys = Map.keys(from_map) ++ Map.keys(to_map)

  #   for key <- keys,
  #       into: %{},
  #       do:
  #         {key,
  #          dump_change_value(
  #            Map.has_key?(from_map, key),
  #            Map.get(from_map, key),
  #            Map.has_key?(to_map, key),
  #            Map.get(to_map, key)
  #          )}
  # end

  # defp dump_change_value(false, _, true, %Ash.Union{} = union),
  #   do: %{to: union.value, type: to_string(union.type)}

  # defp dump_change_value(false, _from, _, to), do: %{to: to}

  # defp dump_change_value(true, %Ash.Union{} = union, false, _to),
  #   do: %{from: union.value, type: to_string(union.type)}

  # defp dump_change_value(true, from, false, _to), do: %{from: from}
  # defp dump_change_value(true, from, true, from), do: %{unchanged: from}
  # defp dump_change_value(true, from, true, to), do: %{from: from, to: to}

  defp dump_value(nil, _attribute), do: nil

  # defp dump_value(%Ash.Union{} = union, attribute) do
  #   {:ok, dumped_value} = Ash.Type.dump_to_embedded(attribute.type, union, attribute.constraints)

  #   {:ok, dumped_value} = Ash.Type.dump_to_embedded(attribute.type, union.value, [])
  #   %{value: dumped_value, type: to_string(union.type)}
  # end

  defp dump_value(value, attribute) do
    {:ok, dumped_value} = Ash.Type.dump_to_embedded(attribute.type, value, attribute.constraints)
    dumped_value
  end

  defp map_get_keys(resource, keys) do
    Enum.map(keys, &Map.get(resource, &1))
  end

  defp build_simple_change_map(false, _from, _, to), do: %{to: to}
  defp build_simple_change_map(true, from, true, from), do: %{unchanged: from}
  defp build_simple_change_map(true, from, true, to), do: %{from: from, to: to}
  defp build_simple_change_map(true, from, false, _to), do: %{from: from}

  defp is_union?(type) do
    type == Ash.Type.Union or
      (Ash.Type.NewType.new_type?(type) && Ash.Type.NewType.subtype_of(type) == Ash.Type.Union)
  end

  defp is_embedded?(type), do: Ash.Type.embedded_type?(type)

  defp primary_keys(%{__struct__: resource}), do: Ash.Resource.Info.primary_key(resource)
  defp primary_keys(resource) when is_struct(resource), do: Ash.Resource.Info.primary_key(resource)
  defp primary_keys(_resource), do: []
end
