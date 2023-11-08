defmodule AshPaperTrail.ChangeBuilders.FullDiff.ListChange do
  @moduledoc """
  A list of changes represented as a map:

    %{ to: nil }
    %{ unchanged: nil }
    %{ from: nil, to: [ ...all.new.items... ] }
    %{ from: [ ...all.new.items.removed.... ], to: nil }
    %{ to: [ ...one.or.more.items.changing... ] }
    %{ unchanged: [ ...no.items.changing... ] }

  With each element of the array represented as a change:

  #TODO: instead of `to:` and `from:` used `added:` and `removed:`
  #

  A nil item added:
    %{ to: nil, index: %{to: index} }

  A nil item unchanged:
    %{ unchanged: nil, index: %{unchanged: index} }

  A simple item added:
    %{ to: value, index: %{to: index} }

  A simple item removed:
    %{ from: value, index: %{from: index} }

  A simple item moved:
    %{ unchanged: value, index: %{from: from, to: to} }

  A simple item unchanged:
    %{ unchanged: value, index: %{unchanged: index} }

  A union item when added:
    %{ to: %{type: type, value: value }, index: %{to: index} }

  A union item when unchanged:
    %{ unchanged: %{type: type, value: value }, index: %{unchanged: index} }

  A union item when removed:
    %{ from: %{type: type, value: value }, index: %{from: index} }

  An embedded item added:
    %{ created: %{ ...attrs...}, index: %{to: index} }

  An embedded item when unchanged and unmoved:
    %{ unchanged: %{...attrs...}, index: %{unchanged: index} }

  An embedded item when updated and unmoved:
    %{ updated: %{...attrs...}, index: %{unchanged: index} }

  An embedded item when unchanged and moved:
    %{ unchanged: %{...attrs...} }, index: %{from: prev, to: index} }

  An embedded item when updated and moved:
    %{ updated: %{...attrs...}, index: %{from: prev, to: index} }

  An embedded item when removed:
    %{ destroyed: value: %{...attrs...}, index: %{from: index} }
  """

  import AshPaperTrail.ChangeBuilders.FullDiff.Helpers

  def build(attribute, changeset) do
    dump_data_value(attribute, changeset)
    |> array_change_map()
  end

  defp dump_data_value(attribute, changeset) do
    data_tuples =
      if changeset.action_type == :create do
        :not_present
      else
        case Ash.Changeset.get_data(changeset, attribute.name) do
          nil ->
            nil

          data ->
            dump_array(data, attribute)
        end
      end

    value_tuples =
      case Ash.Changeset.fetch_change(changeset, attribute.name) do
        {:ok, nil} ->
          nil

        {:ok, values} ->
          dump_array(values, attribute)

        :error ->
          :not_present
      end

    {data_tuples, value_tuples}
  end

  defp dump_array(values, %{type: {:array, attr_type}} = attribute) do
    array_type =
      cond do
        is_union?(attr_type) -> :union
        is_embedded?(attr_type) -> :embedded
        true -> :simple
      end

    dumped_values = dump_value(values, attribute)

    # [{index, uid, data, dumped_data}, ...]
    Enum.zip(values, dumped_values)
    |> Enum.with_index(fn {value, dumped_value}, index ->
      item_type =
        if array_type == :union && embedded_union?(attr_type, dumped_value["type"]) do
          :union_embedded
        else
          array_type
        end

      {index, item_type, unique_id(value, dumped_value), value, dumped_value}
    end)
  end

  defp array_change_map({:not_present, :not_present}), do: %{to: nil}
  defp array_change_map({:not_present, nil}), do: %{to: nil}
  defp array_change_map({:not_present, value_tuples}), do: %{to: diff_lists([], value_tuples)}

  defp array_change_map({nil, :not_present}), do: %{unchanged: nil}
  defp array_change_map({nil, nil}), do: %{unchanged: nil}
  defp array_change_map({nil, value_tuples}), do: %{to: diff_lists([], value_tuples), from: nil}

  defp array_change_map({data_tuples, :not_present}),
    do: %{unchanged: diff_lists(data_tuples, data_tuples)}

  defp array_change_map({data_tuples, nil}), do: %{from: diff_lists(data_tuples, []), to: nil}

  defp array_change_map({data_tuples, value_tuples}) do
    array = diff_lists(data_tuples, value_tuples)

    if Enum.all?(array, fn change ->
         case change do
           %{unchanged: _, index: %{unchanged: _}} -> true
           _ -> false
         end
       end) do
      %{unchanged: array}
    else
      %{to: array}
    end
  end

  defp diff_lists(data_tuples, value_tuples) do
    zip_up_tuples(data_tuples, value_tuples)
    |> Enum.map(&item_change_map/1)
    |> sort_list()
  end

  # [{data_tuple, nil}, {nil, value_tuple}, {data_tuple, value_tuple}]
  defp zip_up_tuples(data_tuples, value_tuples) do
    {zipped_tuples, new_value_tuples} =
      Enum.reduce(data_tuples, {[], value_tuples}, fn data_tuple, {zipped_tuples, value_tuples} ->
        {value_tuples, matching_value_tuple} =
          extract_matching_value_tuple(value_tuples, data_tuple)

        {[{data_tuple, matching_value_tuple} | zipped_tuples], value_tuples}
      end)

    # append the new value_tuples to the end of the list
    Enum.reduce(new_value_tuples, zipped_tuples, fn value_tuple, zipped_tuples ->
      [{:not_present, value_tuple} | zipped_tuples]
    end)
  end

  # Adding a simple type
  defp item_change_map({:not_present, {index, :simple, _, _, dumped_value}}) do
    %{added: dumped_value} |> add_index_change(nil, index)
  end

  # Adding a Union type
  defp item_change_map({:not_present, {index, :union, _uid, _, dumped_value}}) do
    union_change_map({:not_present, {:non_embedded, dumped_value["type"], dumped_value["value"]}})
    |> add_index_change(nil, index)
  end

  # Adding a Embedded Union type
  defp item_change_map({:not_present, {index, :union_embedded, uid, _, dumped_value}}) do
    union_change_map(
      {:not_present, {:embedded, dumped_value["type"], uid, dumped_value["value"]}}
    )
    |> add_index_change(nil, index)
  end

  # Adding an embedded type
  defp item_change_map({:not_present, {index, :embedded, uid, _, dumped_value}}) do
    embedded_change_map({:not_present, {uid, dumped_value}}) |> add_index_change(nil, index)
  end

  # Removing a simple type
  defp item_change_map({{index, :simple, _, _, dumped_data}, :not_present}) do
    %{removed: dumped_data} |> add_index_change(nil, index)
  end

  # Removing a Union type
  defp item_change_map({{index, :union, _uid, _, dumped_data}, :not_present}) do
    union_change_map({{:non_embedded, dumped_data["type"], dumped_data["value"]}, :removed})
    |> add_index_change(index, nil)
  end

  # Removing an embedded Union type
  defp item_change_map({{index, :union_embedded, uid, _, dumped_data}, :not_present}) do
    union_change_map({{:embedded, dumped_data["type"], uid, dumped_data["value"]}, :removed})
    |> add_index_change(index, nil)
  end

  # Removing an embedded type
  defp item_change_map({{index, :embedded, uid, _, dumped_data}, :not_present}) do
    embedded_change_map({{uid, dumped_data}}) |> add_index_change(index, nil)
  end

  # Removing a simple type
  defp item_change_map(
         {{index, :simple, _, _, dumped_data}, {index2, :simple, _, _, dumped_data}}
       ) do
    %{unchanged: dumped_data} |> add_index_change(index, index2)
  end

  # Updating an embedded type
  defp item_change_map(
         {{index, :embedded, uid, _, dumped_data}, {index2, :embedded, uid2, _, dumped_value}}
       ) do
    embedded_change_map({{uid, dumped_data}, {uid2, dumped_value}})
    |> add_index_change(index, index2)
  end

  # Updating an embedded union type
  defp item_change_map(
         {{index, :union_embedded, uid, _, dumped_data},
          {index2, :union_embedded, uid2, _, dumped_value}}
       ) do
    union_change_map(
      {{:embedded, dumped_data["type"], uid, dumped_data["value"]},
       {:embedded, dumped_value["type"], uid2, dumped_value["value"]}}
    )
    |> add_index_change(index, index2)
  end

  # Updating a union type
  defp item_change_map(
         {{index, :union, _uid, _, dumped_data}, {index2, :union, _uid2, _, dumped_value}}
       ) do
    union_change_map(
      {{:non_embedded, dumped_data["type"], dumped_data["value"]},
       {:non_embedded, dumped_value["type"], dumped_value["value"]}}
    )
    |> add_index_change(index, index2)
  end

  def add_index_change(change, from, to) do
    Map.put(change, :index, build_index_change(from, to))
  end

  # Sort the list by index changes. Sort by where they _are_ currently in
  # in the list, and if removed where they were. Put the removed item
  # before the current item.
  defp sort_list(list) do
    Enum.sort_by(list, fn change ->
      case change do
        # moved indexes
        %{index: %{from: _, to: i}} -> [i, 1]
        # removed from list
        %{index: %{from: i}} -> [i, 0]
        # added to list
        %{index: %{to: i}} -> [i, 1]
        # unchanged
        %{index: %{unchanged: i}} -> [i, 1]
      end
    end)
  end

  defp extract_matching_value_tuple(value_tuples, {data_index, _, _, _, _} = data_tuple) do
    matching_index = matching_value_indexes(value_tuples, data_tuple) |> nearest_index(data_index)

    case matching_index do
      nil ->
        {value_tuples, :not_present}

      index ->
        Enum.reduce(value_tuples, {[], nil}, fn {i, _, _, _, _} = tuple,
                                                {acc, matching_value_tuple} ->
          cond do
            matching_value_tuple ->
              {acc ++ [tuple], matching_value_tuple}

            i == index ->
              {acc, tuple}

            true ->
              {acc ++ [tuple], nil}
          end
        end)
    end
  end

  # Looks at a list of tuples to find ones that match the data, returns
  # the indexes of the matching tuples.
  # A tuple looks like: {index, uid, data, dumped_data}
  defp matching_value_indexes([], _), do: []

  defp matching_value_indexes(value_tuples, {_, _, data_uid, _, _}) do
    Enum.reduce(value_tuples, [], fn {index, _, uid, _, _}, acc ->
      if data_uid == uid do
        [index | acc]
      else
        acc
      end
    end)
  end

  defp nearest_index([], _), do: nil

  defp nearest_index(indexes, i2) do
    Enum.sort_by(indexes, fn i1 -> abs(i1 - i2) end)
    |> List.first()
  end
end
