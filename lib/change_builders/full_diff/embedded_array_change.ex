defmodule AshPaperTrail.ChangeBuilders.FullDiff.EmbeddedArrayChange do
  @moduledoc """
  A array of embedded resources be represented as a map:

    %{ to: nil }
    %{ unchanged: nil }
    %{ from: nil, to: [ ...all.new.items... ] }
    %{ to: [ ...oneo.or.more.items.changing... ] }
    %{ unchanged: [ ...no.items.changing... ] }

  With each element of the array represented as a embedded change:

  An item added:
    %{ created: %{ ...attrs...}, index: %{to: index} }

  An item when unchanged and unmoved:
    %{ unchanged: %{...attrs...}, index: %{unchanged: index} }

  An item when updated and unmoved:
    %{ updated: %{...attrs...}, index: %{unchanged: index} }

  An item when unchanged and moved:
    %{ unchanged: %{...attrs...} }, index: %{from: prev, to: index} }

  An item when updated and moved:
    %{ updated: %{...attrs...}, index: %{from: prev, to: index} }

  An item when removed:
    %{ destroyed: value: %{...attrs...}, index: %{from: index} }
  """

  import AshPaperTrail.ChangeBuilders.FullDiff.Helpers

  def build(attribute, changeset) do
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

  # Builds a simple change map based on the given values.
  #
  # change_map({data_present, data, value_present, value})

  defp embedded_change_map({false, _data, false, _value}), do: %{to: nil}
  defp embedded_change_map({true, nil, _, nil}), do: %{unchanged: nil}

  defp embedded_change_map({false, _data, _, %{} = value}),
    do: %{created: attribute_changes(%{}, value)}

  defp embedded_change_map({true, nil, _, %{} = value}),
    do: %{created: attribute_changes(%{}, value), from: nil}

  defp embedded_change_map({true, data, false, _value}),
    do: %{unchanged: attribute_changes(data, data)}

  defp embedded_change_map({true, data, true, data}),
    do: %{unchanged: attribute_changes(data, data)}

  defp embedded_change_map({true, data, true, nil}),
    do: %{destroyed: attribute_changes(data, nil), to: nil}

  defp embedded_change_map({true, data, true, value}),
    do: %{updated: attribute_changes(data, value)}
end
