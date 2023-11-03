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
    {data_present, data_embedded, dumped_data_type, dumped_data} =
      if changeset.action_type == :create do
        {false, false, nil, nil}
      else
        data = Ash.Changeset.get_data(changeset, attribute.name)

        case dump_union_value(data, attribute) do
          {:non_embedded, _, dumped_data} ->
            {true, false, nil, dumped_data}

          {:embedded, dumped_data_type, dumped_data_value} ->
            {true, true, dumped_data_type, dumped_data_value}
        end
      end

    {value_present, value_embedded, dumped_value_type, dumped_value} =
      case Ash.Changeset.fetch_change(changeset, attribute.name) do
        {:ok, value} ->
          case dump_union_value(value, attribute) do
            {:non_embedded, _, dumped_value} ->
              {true, false, nil, dumped_value}

            {:embedded, dumped_value_type, dumped_value} ->
              {true, true, dumped_value_type, dumped_value}
          end

        :error ->
          {data_present, data_embedded, dumped_data_type, dumped_data}
      end

    # IO.inspect([data_present, data_embedded, dumped_data_type, dumped_data, value_present, value_embedded, dumped_value_type, dumped_value], label: "build_embedded_union_changes")

    build_embedded_union_changes(
      data_present,
      data_embedded,
      dumped_data_type,
      dumped_data,
      value_present,
      value_embedded,
      dumped_value_type,
      dumped_value
    )
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
    do: %{created: build_embedded_attribute_changes(%{}, value), from: nil}

  defp build_embedded_changes(%{} = data, nil),
    do: %{destroyed: build_embedded_attribute_changes(data, %{})}

  defp build_embedded_changes(%{} = data, data),
    do: %{unchanged: build_embedded_attribute_changes(data, data)}

  defp build_embedded_changes(%{} = data, %{} = value),
    do: %{updated: build_embedded_attribute_changes(data, value)}

  defp build_embedded_union_changes(
         data_present,
         false,
         _data_type,
         data,
         value_present,
         false,
         _value_type,
         value
       ),
       do: build_simple_change_map(data_present, data, value_present, value)

  defp build_embedded_union_changes(
         _data_present,
         _data_embedded,
         _data_type,
         nil,
         _value_present,
         _value_embedded,
         _value_type,
         nil
       ),
       do: %{unchanged: nil}

  defp build_embedded_union_changes(
         true = _data_present,
         _data_embedded,
         _data_type,
         nil,
         true = _value_present,
         true = _value_embedded,
         value_type,
         %{} = value
       ),
       do: %{
         created: build_embedded_attribute_changes(%{}, value),
         from: nil,
         type: %{to: to_string(value_type)}
       }

  defp build_embedded_union_changes(
         true = _data_present,
         false = _data_embedded,
         _data_type,
         data,
         true = _value_present,
         true = _value_embedded,
         value_type,
         %{} = value
       ),
       do: %{
         created: build_embedded_attribute_changes(%{}, value),
         type: %{to: to_string(value_type)},
         from: %{type: to_string(data[:type]), value: data[:value]}
       }

  defp build_embedded_union_changes(
         false = _data_present,
         _data_embedded,
         _data_type,
         nil,
         _value_present,
         _value_embedded,
         value_type,
         %{} = value
       ),
       do: %{
         created: build_embedded_attribute_changes(%{}, value),
         type: %{to: to_string(value_type)}
       }

  defp build_embedded_union_changes(
         _data_present,
         _data_embedded,
         _data_type,
         %{} = data,
         _value_present,
         _value_embedded,
         _value_type,
         nil
       ),
       do: %{destroyed: build_embedded_attribute_changes(data, %{})}

  defp build_embedded_union_changes(
         _data_present,
         _data_embedded,
         data_type,
         %{} = data,
         _value_present,
         _value_embedded,
         data_type,
         data
       ),
       do: %{
         unchanged: build_embedded_attribute_changes(data, data),
         type: %{unchanged: to_string(data_type)}
       }

  defp build_embedded_union_changes(
         _data_present,
         _data_embedded,
         data_type,
         %{} = data,
         _value_present,
         _value_embedded,
         data_type,
         %{} = value
       ),
       do: %{
         updated: build_embedded_attribute_changes(data, value),
         type: %{unchanged: to_string(data_type)}
       }

  defp build_embedded_union_changes(
         true,
         _data_embedded,
         data_type,
         %{} = data,
         _value_present,
         true,
         value_type,
         %{} = value
       ),
       do: %{
         created: build_embedded_attribute_changes(%{}, value),
         destroyed: build_embedded_attribute_changes(data, %{}),
         type: %{from: to_string(data_type), to: to_string(value_type)}
       }

  defp build_embedded_union_changes(
         true,
         _data_embedded,
         data_type,
         %{} = data,
         _value_present,
         false,
         _value_type,
         %{} = value
       ),
       do: %{
         to: %{type: to_string(value[:type]), value: value[:value]},
         destroyed: build_embedded_attribute_changes(data, %{}),
         type: %{from: to_string(data_type)}
       }

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
                                                  {indexes, lookup, ids} ->
        primary_keys = primary_keys(data)
        keys = map_get_keys(data, primary_keys)

        {
          Map.put(indexes, keys, index),
          Map.put(lookup, keys, dumped_data),
          MapSet.put(ids, keys)
        }
      end)

    values =
      case Ash.Changeset.fetch_change(changeset, attribute.name) do
        {:ok, values} -> values
        :error -> nil
      end

    {dumped_values, dumped_ids} =
      Enum.zip(List.wrap(values), List.wrap(dump_value(List.wrap(values), attribute)))
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

    cond do
      changeset.action_type == :create ->
        %{to: sort_embedded_array_changes(dumped_values)}

      is_nil(values) && is_nil(data) ->
        %{unchanged: nil}

      is_nil(data) ->
        %{from: nil, to: sort_embedded_array_changes(dumped_values)}

      is_nil(values) ->
        %{to: nil, from: sort_embedded_array_changes(dumped_values)}

      true ->
        build_embedded_array_changes(dumped_data, dumped_values)
    end
  end

  def build_embedded_array_changes(dumped_values, dumped_values), do: %{unchanged: dumped_values}

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
    dumped_data = dump_union_value(data, attribute)

    {data_indexes, data_lookup, data_ids} =
      Enum.zip(List.wrap(data), List.wrap(dumped_data))
      |> Enum.with_index(fn {data, dumped_tuple}, index -> {index, data, dumped_tuple} end)
      |> Enum.reduce({%{}, %{}, MapSet.new()}, fn {index, data, dumped_tuple},
                                                  {indexes, lookup, ids} ->
        keys =
          case dumped_tuple do
            {:embedded, embedded_type, _dumped_value} ->
              primary_keys = union_primary_keys(data, embedded_type)
              map_get_keys(data, primary_keys)

            {:non_embedded, _, _} ->
              []
          end

        {
          Map.put(indexes, keys, index),
          Map.put(lookup, keys, dumped_tuple),
          MapSet.put(ids, keys)
        }
      end)

    values =
      case Ash.Changeset.fetch_change(changeset, attribute.name) do
        {:ok, values} -> values
        :error -> []
      end

    dumped_tuples = dump_union_value(values, attribute)

    {dumped_values, dumped_ids} =
      Enum.zip(List.wrap(values), dumped_tuples)
      |> Enum.with_index(fn {value, dumped_tuple}, index -> {index, value, dumped_tuple} end)
      |> Enum.reduce({[], MapSet.new()}, fn {to_index, value, dumped_tuple},
                                            {dumped_values, dumped_ids} ->
        case dumped_tuple do
          {:non_embedded, _, dumped_value} ->
            change =
              build_embedded_union_changes(
                false,
                false,
                nil,
                nil,
                true,
                false,
                nil,
                dumped_value
              )

            index_change = build_index_change(nil, to_index)

            {
              [Map.put(change, :index, index_change) | dumped_values],
              dumped_ids
            }

          {:embedded, embedded_type, dumped_value} ->
            case union_primary_keys(value, embedded_type) do
              [] ->
                change =
                  build_embedded_union_changes(
                    false,
                    false,
                    nil,
                    nil,
                    true,
                    true,
                    embedded_type,
                    dumped_value
                  )

                index_change = build_index_change(nil, to_index)

                {
                  [Map.put(change, :index, index_change) | dumped_values],
                  dumped_ids
                }

              primary_keys ->
                keys = map_get_keys(value, primary_keys)

                {data_present, data_embedded, dumped_data_type, dumped_data_value} =
                  case Map.get(data_lookup, keys) do
                    nil ->
                      {false, false, nil, nil}

                    {_, _, nil} ->
                      {false, false, nil, nil}

                    {data_embedded, data_type, dumped_data} ->
                      {true, data_embedded, data_type, dumped_data}
                  end

                change =
                  case dumped_tuple do
                    {:non_embedded, _, dumped_value} ->
                      build_embedded_union_changes(
                        data_present,
                        data_embedded,
                        dumped_data_type,
                        dumped_data_value,
                        true,
                        false,
                        nil,
                        dumped_value
                      )

                    {:embedded, embedded_type, dumped_value} ->
                      build_embedded_union_changes(
                        data_present,
                        data_embedded,
                        dumped_data_type,
                        dumped_data_value,
                        true,
                        true,
                        embedded_type,
                        dumped_value
                      )
                  end

                index_change = Map.get(data_indexes, keys) |> build_index_change(to_index)

                {
                  [Map.put(change, :index, index_change) | dumped_values],
                  MapSet.put(dumped_ids, keys)
                }
            end
        end
      end)

    dumped_values =
      MapSet.difference(data_ids, dumped_ids)
      |> Enum.reduce(dumped_values, fn keys, dumped_values ->
        {data_embedded, dumped_data_type, dumped_data_value} = Map.get(data_lookup, keys)

        change =
          build_embedded_union_changes(
            true,
            data_embedded,
            dumped_data_type,
            dumped_data_value,
            false,
            false,
            nil,
            nil
          )

        index_change = Map.get(data_indexes, keys) |> build_index_change(nil)

        [Map.put(change, :index, index_change) | dumped_values]
      end)

    if changeset.action_type == :create do
      %{to: sort_embedded_array_changes(dumped_values)}
    else
      build_embedded_array_changes(dumped_data, dumped_values)
    end
  end

  defp dump_value(nil, _attribute), do: nil

  defp dump_value(value, attribute) do
    {:ok, dumped_value} = Ash.Type.dump_to_embedded(attribute.type, value, attribute.constraints)
    dumped_value
  end

  defp dump_union_value(nil, _attribute), do: {:non_embedded, nil, nil}

  defp dump_union_value(values, attribute) when is_list(values) do
    dump_value(values, attribute)
    |> Enum.map(fn union_value ->
      if is_embedded_union?(attribute.type, union_value["type"]) do
        {:embedded, union_value["type"], union_value["value"]}
      else
        {:non_embedded, union_value["type"],
         %{value: union_value["value"], type: to_string(union_value["type"])}}
      end
    end)
  end

  defp dump_union_value(value, attribute) do
    union_value = dump_value(value, attribute)

    if is_embedded_union?(attribute.type, union_value["type"]) do
      {:embedded, union_value["type"], union_value["value"]}
    else
      {:non_embedded, union_value["type"],
       %{value: union_value["value"], type: to_string(union_value["type"])}}
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

  defp union_primary_keys(%Ash.Union{} = union, subtype) do
    with true <- :erlang.function_exported(union, :subtype_constraints, 0),
         subtype_constraints <- union.subtype_constraints(),
         subtypes when not is_nil(subtypes) <- Keyword.get(subtype_constraints, :types),
         subtype_config when not is_nil(subtype) <- Keyword.get(subtypes, subtype),
         subtype_config_type when not is_nil(subtype_config_type) <-
           Keyword.get(subtype_config, :type) do
      primary_keys(subtype_config_type)
    else
      _ -> []
    end
  end

  defp primary_keys(%{__struct__: resource}), do: Ash.Resource.Info.primary_key(resource)

  defp primary_keys(resource) when is_struct(resource),
    do: Ash.Resource.Info.primary_key(resource)

  defp primary_keys(_resource), do: []
end
