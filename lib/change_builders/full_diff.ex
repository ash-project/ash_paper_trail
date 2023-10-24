defmodule AshPaperTrail.Dumpers.FullDiff do
  def build_changes(attributes, changeset) do
    Enum.reduce(attributes, %{}, fn attribute, changes ->
      Map.put(
        changes,
        attribute.name,
        build_attribute_change(attribute, changeset)
      )
    end)
  end

  def build_attribute_change(%{type: {:array, attr_type}} = attribute, changeset) do
    cond do
      is_union?(attr_type) ->
        build_union_array_change(attribute, changeset)

      is_embedded?(attr_type) ->
        build_embedded_array_change(attribute, changeset)

      true ->
        build_simple_change(attribute, changeset)
    end
  end

  def build_attribute_change(attribute, changeset) do
    cond do
      # embedded types are created, updated, destroyed, and have their individual attributes tracked
      is_embedded?(attribute.type) ->
        build_embedded_change(attribute, changeset)

      # embedded types are special in that they have a value and a type
      is_union?(attribute.type) ->
        build_union_change(attribute, changeset)

      true ->
        # non-embedded types are treated as a single value
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

  # A non-embedded union attribute change will be represented as a map:
  #
  #   %{ to: %{value: value, type: type } }
  #   %{ from: %{value: value, type: type }, to: %{value: value, type: type } }
  #   %{ unchanged: %{value: value, type: type } }
  #
  # While a embedded union attribute change will be represented as:
  #
  #   %{ to: nil }
  #   %{ created: %{ attr: %{to: ""}, ...}, type: "..." }
  #   %{ updated: %{ attr: %{to: ""}, ...}, type: "..." }
  #   %{ destroyed: %{ attr: %{to: ""}, ...}, type: "..." }
  def build_union_change(attribute, changeset) do
    {data_present, dumped_data} =
      if changeset.action_type == :create do
        {false, nil}
      else
        data = Ash.Changeset.get_data(changeset, attribute.name)
        {:non_embedded, dumped_data} = dump_union_value(data, attribute)
        {true, dumped_data}
      end

    case Ash.Changeset.fetch_change(changeset, attribute.name) do
      {:ok, value} ->
        case dump_union_value(value, attribute) do
        {:non_embedded, dumped_value} ->
          build_simple_change_map(
            data_present,
            dumped_data,
            true,
            dumped_value
          )
        {:embedded, dumped_value_type, dumped_value} ->
          build_embedded_union_changes(dumped_data, dumped_value_type, dumped_value)

        end
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


  defp build_embedded_union_changes(nil, _value_type, nil), do: %{unchanged: nil}

  defp build_embedded_union_changes(nil, value_type, %{} = value),
    do: %{created: build_embedded_attribute_changes(%{}, value), type: to_string(value_type)}

  defp build_embedded_union_changes(%{} = data, _value_type, nil),
    do: %{destroyed: build_embedded_attribute_changes(data, %{})}

  defp build_embedded_union_changes(%{} = data, _value_type, data),
    do: %{unchanged: build_embedded_attribute_changes(data, data)}

  defp build_embedded_union_changes(%{} = data, _value_type, %{} = value),
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

  # A array of embedded resources be represented as a map:
  #
  #   %{ to: [ %{}, %{}, %{}] }
  #   %{ unchanged: [ %{}, %{}, %{}] }
  #
  # Each element of the array will be represented as a simple change, union change or an embedded change.
  # It will incude a union key if applicable.  Embedded resources with primary_keys will also
  # include an `index` key set to `%{from: x, to: y}` or `%{to: x}` or `%{ucnhanged: x}`.
  def build_embedded_array_change(attribute, changeset) do
    data = Ash.Changeset.get_data(changeset, attribute.name)
    dumped_data = dump_value(data, attribute)

    {data_indexes, data_lookup, data_ids} =
      Enum.zip(List.wrap(data), List.wrap(dumped_data))
      |> Enum.with_index(fn {data, dumped_data}, index -> {index, data, dumped_data} end)
      |> Enum.reduce({%{}, %{}, MapSet.new()}, fn {index, data, dumped_data},
                                                  {data_indexes, data_lookup, data_ids} ->
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
      Enum.zip(List.wrap(values), List.wrap(dump_value(values, attribute)))
      |> Enum.with_index(fn {value, dumped_value}, index -> {index, value, dumped_value} end)
      |> Enum.reduce({[], MapSet.new()}, fn {to_index, value, dumped_value},
                                            {dumped_values, dumped_ids} ->
        case primary_keys(value) do
          [] ->
            %{created: build_embedded_attribute_changes(%{}, dumped_value)}

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
      %{to: sort_embedded_array_changes(dumped_values)}
    else
      build_embedded_array_changes(dumped_data, dumped_values)
    end
  end

  def build_embedded_array_changes(dumped_values, dumped_values), do: %{unchanged: dumped_values}
  def build_embedded_array_changes(nil, []), do: %{unchanged: []}

  def build_embedded_array_changes(_dumped_data, dumped_values) do
    %{to: sort_embedded_array_changes(dumped_values)}
  end

  def build_index_change(nil, to), do: %{to: to}
  def build_index_change(from, from), do: %{unchanged: from}
  def build_index_change(from, to), do: %{from: from, to: to}

  def sort_embedded_array_changes(dumped_values) do
    Enum.sort_by(dumped_values, fn change ->
      case change do
        %{destroyed: _embedded, index: %{from: i}} -> [i, 0]
        %{index: %{to: i}} -> [i, 1]
        %{index: %{unchanged: i}} -> [i, 1]
      end
    end)
  end

  # A array of union resources be represented as a map:
  #
  #   %{ to: [ %{}, %{}, %{}] }
  #   %{ unchanged: [ %{}, %{}, %{}] }
  #
  # Each element of the array will be represented as a union change.
  def build_union_array_change(attribute, changeset) do
    data = Ash.Changeset.get_data(changeset, attribute.name)
    {:non_embedded, dumped_data} = dump_union_value(data, attribute)

    values =
      case Ash.Changeset.fetch_change(changeset, attribute.name) do
        {:ok, values} -> values
        :error -> []
      end

    {:non_embedded, dumped_values} = dump_union_value(values, attribute)

    # We need to pad the shorter list with nils so that we can zip them together
    max_len =
      [dumped_data, dumped_values]
      |> Enum.map(&List.wrap(&1))
      |> Enum.map(&length(&1))
      |> Enum.max()

    changes =
      [dumped_data, dumped_values]
      |> Enum.map(&List.wrap(&1))
      |> Enum.map(&(&1 ++ List.duplicate(nil, max_len - length(&1))))
      |> Enum.zip()
      |> Enum.map(fn {dumped_data, dumped_value} ->
        build_simple_change_map(
          dumped_data != nil,
          dumped_data,
          dumped_value != nil,
          dumped_value
        )
      end)

    %{to: changes}
  end

  defp dump_value(nil, _attribute), do: nil

  defp dump_value(value, attribute) do
    {:ok, dumped_value} = Ash.Type.dump_to_embedded(attribute.type, value, attribute.constraints)
    dumped_value
  end

  defp dump_union_value(nil, _attribute), do: {:non_embedded, nil}

  defp dump_union_value(values, attribute) when is_list(values) do
    {:non_embedded,
     dump_value(values, attribute)
     |> Enum.map(fn value ->
       %{value: value["value"], type: to_string(value["type"])}
     end)}
  end

  defp dump_union_value(value, attribute) do
    union_value = dump_value(value, attribute)

    if is_embedded_union?(attribute.type, union_value["type"]) do
      {:embedded, union_value["type"], union_value["value"]}
    else

      {:non_embedded, %{value: union_value["value"], type: to_string(union_value["type"])}}

    end
  end

  defp map_get_keys(resource, keys) do
    Enum.map(keys, &Map.get(resource, &1))
  end

  defp build_simple_change_map(false, _from, _, to), do: %{to: to}
  defp build_simple_change_map(true, from, true, from), do: %{unchanged: from}
  defp build_simple_change_map(true, from, true, to), do: %{from: from, to: to}
  defp build_simple_change_map(true, from, false, _to), do: %{from: from}

  defp is_embedded_union?(type, subtype) do
    with true <- is_union?(type),
         true <- :erlang.function_exported(type, :subtype_constraints, 0),
         subtype_constraints <- type.subtype_constraints(),
         subtypes when not is_nil(subtypes) <- Keyword.get(subtype_constraints, :types),
         subtype_config when not is_nil(subtype) <- Keyword.get(subtypes, subtype),
         subtype_config_type when not is_nil(subtype_config_type) <-
           Keyword.get(subtype_config, :type) do
      is_embedded?(subtype_config_type)
    else
      _ -> false
    end
  end

  defp is_union?(type) do
    type == Ash.Type.Union or
      (Ash.Type.NewType.new_type?(type) && Ash.Type.NewType.subtype_of(type) == Ash.Type.Union)
  end

  defp is_embedded?(type), do: Ash.Type.embedded_type?(type)

  defp primary_keys(%{__struct__: resource}), do: Ash.Resource.Info.primary_key(resource)

  defp primary_keys(resource) when is_struct(resource),
    do: Ash.Resource.Info.primary_key(resource)

  defp primary_keys(_resource), do: []
end
