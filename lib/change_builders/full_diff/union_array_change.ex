defmodule AshPaperTrail.ChangeBuilders.FullDiff.UnionArrayChange do
  @moduledoc """
  A array of union resources be represented as a map:

    %{ to: nil }
    %{ to: [ ...items... ] }
    %{ from: nil, to: [ ...items... ] }
    %{ unchanged: [ ...items... ] }

  With each element of the array represented as a union change:

  A nil item added:
    %{ to: nil, index: %{to: index} }

  A nil item unchanged:
    %{ unchanged: nil, index: %{unchanged: index} }

  A non-embedded item when added:
    %{ to: %{type: type, value: value }, index: %{to: index} }

  A non-embedded item when unchanged:
    %{ unchanged: %{type: type, value: value }, index: %{unchanged: index} }

  A non-embedded item when removed:
    %{ from: %{type: type, value: value }, index: %{from: index} }

  An embedded item added:
    %{ created: %{type: type, value: %{ ...attrs...} }, index: %{to: index} }

  An embedded item when unchanged and unmoved:
    %{ unchanged: %{type: type, value: %{...attrs...} }, index: %{unchanged: index} }

  An embedded item when updated and unmoved:
    %{ updated: %{type: type, value: %{...attrs...} }, index: %{unchanged: index} }

  An embedded item when unchanged and moved:
    %{ unchanged: %{type: type, value: %{...attrs...} }, index: %{from: prev, to: index} }

  An embedded item when updated and moved:
    %{ updated: %{type: type, value: %{...attrs...} }, index: %{from: prev, to: index} }

  An embedded item when removed:
    %{ destroyed: %{type: type, value: %{...attrs...} }, index: %{from: index} }
  """

  import AshPaperTrail.ChangeBuilders.FullDiff.Helpers

  def build(attribute, changeset) do
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
end
