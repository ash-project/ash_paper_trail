defmodule ChangeBuilders.FullDiff.ArrayChange do
  import AshPaperTrail.ChangeBuilders.FullDiff.Helpers

  def build(%{type: {:array, attr_type}} = attribute, changeset) do
    if is_union?(attr_type) do
      build_union_array_change(attribute, changeset)
    else
      build_embedded_array_change(attribute, changeset)
    end
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

            change = embedded_change_map({true, dumped_data, true, dumped_value})
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

        change = embedded_change_map({true, dumped_data, false, nil})

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
  def build_index_change(from, nil), do: %{from: from}
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

  defp map_get_keys(resource, keys) do
    Enum.map(keys, &Map.get(resource, &1))
  end

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
