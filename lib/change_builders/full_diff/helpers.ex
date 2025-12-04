# SPDX-FileCopyrightText: 2022 ash_paper_trail contributors <https://github.com/ash-project/ash_paper_trail/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshPaperTrail.ChangeBuilders.FullDiff.Helpers do
  @moduledoc """
  Misc helpers for building a full diff of a changeset.
  """

  # When field policies hide a value, Ash will put a %Ash.ForbiddenField{}
  # placeholder into the struct. For full_diff we represent those as nil.
  def dump_value(%Ash.ForbiddenField{}, _attribute), do: nil

  def dump_value(nil, _attribute), do: nil

  def dump_value(values, %{type: {:array, attr_type}} = attribute) do
    item_constraints = attribute.constraints[:items]

    # This is a work around for a bug in Ash.Type.dump_to_embedded/3
    Enum.map(values, fn value ->
      case value do
        %Ash.ForbiddenField{} ->
          nil

        _ ->
          {:ok, dumped_value} =
            Ash.Type.dump_to_embedded(attr_type, value, item_constraints)

          dumped_value
      end
    end)
  end

  def dump_value(value, attribute) do
    case value do
      %Ash.ForbiddenField{} ->
        nil

      _ ->
        {:ok, dumped_value} =
          Ash.Type.dump_to_embedded(attribute.type, value, attribute.constraints)

        dumped_value
    end
  end

  @doc """
  Builds a simple change map based on the given values.

  attribute_change_map({data_present, data, value_present, value})
  """
  def attribute_change_map({false, _data, _, value}), do: %{to: value}
  def attribute_change_map({true, data, false, _}), do: %{unchanged: data}
  def attribute_change_map({true, data, true, data}), do: %{unchanged: data}
  def attribute_change_map({true, data, true, value}), do: %{from: data, to: value}

  def union?(type) do
    type == Ash.Type.Union or
      (Ash.Type.NewType.new_type?(type) && Ash.Type.NewType.subtype_of(type) == Ash.Type.Union)
  end

  def embedded?(type), do: Ash.Type.embedded_type?(type)

  def embedded_union?(type, subtype) do
    with true <- union?(type),
         true <- :erlang.function_exported(type, :subtype_constraints, 0),
         subtype_constraints <- type.subtype_constraints(),
         subtypes when not is_nil(subtypes) <- Keyword.get(subtype_constraints, :types),
         subtype_config when not is_nil(subtype) <- Keyword.get(subtypes, subtype),
         subtype_config_type when not is_nil(subtype_config_type) <-
           Keyword.get(subtype_config, :type) do
      embedded?(subtype_config_type)
    else
      _ -> false
    end
  end

  @doc """
  Building a map of attribute changes for the embedded resource
  """
  def attribute_changes(%{} = data_map, nil) do
    for key <- keys_in([data_map]),
        into: %{},
        do: {key, %{from: Map.get(data_map, key)}}
  end

  def attribute_changes(%{} = data_map, %{} = value_map) do
    for key <- keys_in([data_map, value_map]),
        into: %{},
        do: attribute_change(key, data_map, value_map)
  end

  defp attribute_change(key, data_map, value_map) do
    {data_present, dumped_data} = map_key(data_map, key)
    {value_present, dumped_value} = map_key(value_map, key)

    change = attribute_change_map({data_present, dumped_data, value_present, dumped_value})

    {key, change}
  end

  defp keys_in(map_list) do
    Enum.reduce(map_list, MapSet.new(), fn map, keys ->
      Map.keys(map)
      |> MapSet.new()
      |> MapSet.union(keys)
    end)
  end

  defp map_key(%{} = map, key) do
    {Map.has_key?(map, key), Map.get(map, key)}
  end

  # returns a list of primary keys for the given resource, or nil if there are none
  def unique_id(%Ash.Union{value: %{__struct__: _} = value}, dumped_value),
    do: unique_id(value, dumped_value)

  def unique_id(%Ash.Union{}, dumped_value), do: dumped_value
  def unique_id(nil, _dumped_value), do: nil

  def unique_id(%{__struct__: resource} = struct, dump_value) do
    if Ash.Resource.Info.resource?(resource) do
      case Ash.Resource.Info.primary_key(resource) do
        [] ->
          nil

        primary_keys ->
          Enum.reduce(primary_keys, [resource], &(&2 ++ [Map.get(dump_value, &1)]))
      end
    else
      # For non-Ash structs (Time, Date, DateTime, Decimal, etc.),
      # return the struct itself for value-based equality matching
      struct
    end
  end

  def unique_id(simple_value, _dump_value), do: simple_value

  def build_index_change(nil, to), do: %{to: to}
  def build_index_change(from, nil), do: %{from: from}
  def build_index_change(from, from), do: %{unchanged: from}
  def build_index_change(from, to), do: %{from: from, to: to}

  def map_get_keys(resource, keys) do
    Enum.map(keys, &Map.get(resource, &1))
  end

  # Builds a simple change map based on the given values.
  #
  # change_map({data_present, data, value_present, value})

  def embedded_change_map({:not_present, :not_present}), do: %{to: nil}
  def embedded_change_map({:not_present, nil}), do: %{to: nil}

  def embedded_change_map({:not_present, {_uid, %{} = value}}),
    do: %{created: attribute_changes(%{}, value)}

  def embedded_change_map({nil, :not_present}), do: %{unchanged: nil}
  def embedded_change_map({nil, nil}), do: %{unchanged: nil}

  def embedded_change_map({nil, {_uid, %{} = value}}),
    do: %{created: attribute_changes(%{}, value), from: nil}

  def embedded_change_map({{_uid, data}, :not_present}),
    do: %{unchanged: attribute_changes(data, data)}

  def embedded_change_map({{_uid, data}}),
    do: %{destroyed: attribute_changes(data, nil)}

  def embedded_change_map({{_uid, data}, nil}),
    do: %{destroyed: attribute_changes(data, nil), to: nil}

  def embedded_change_map({{nil, data}, {nil, value}}),
    do: %{destroyed: attribute_changes(data, nil), created: attribute_changes(%{}, value)}

  def embedded_change_map({{uid, data}, {uid, data}}),
    do: %{unchanged: attribute_changes(data, data)}

  def embedded_change_map({{uid, data}, {uid, value}}),
    do: %{updated: attribute_changes(data, value)}

  def embedded_change_map({{_data_pk, data}, {_value_pk, value}}),
    do: %{destroyed: attribute_changes(data, nil), created: attribute_changes(%{}, value)}

  # def union_change_map({{_data_present, _data_type, _data}, { _value_present, _value_type, _value}}),

  # Non-present to still no value
  def union_change_map({:not_present, :not_present}),
    do: %{to: nil}

  # Non-present to nil
  def union_change_map({:not_present, {:non_embedded, nil, nil}}),
    do: %{to: nil}

  # Not present to non_embedded
  def union_change_map({:not_present, {:non_embedded, type, value}}),
    do: %{to: %{type: to_string(type), value: value}}

  # Not present to embedded
  def union_change_map({:not_present, {:embedded, type, _uid, value}}),
    do: %{to: %{type: to_string(type), created: attribute_changes(%{}, value)}}

  # nil unchanged
  def union_change_map({{:non_embedded, nil, nil}, :not_present}),
    do: %{unchanged: nil}

  # nil to nil
  def union_change_map({{:non_embedded, nil, nil}, {:non_embedded, nil, nil}}),
    do: %{unchanged: nil}

  # nil to embedded
  def union_change_map({{:non_embedded, nil, nil}, {:embedded, type, _uid, value}}),
    do: %{
      from: nil,
      to: %{type: to_string(type), created: attribute_changes(%{}, value)}
    }

  # nil to non_embedded
  def union_change_map({{:non_embedded, nil, nil}, {:non_embedded, type, value}}),
    do: %{
      from: nil,
      to: %{type: to_string(type), value: value}
    }

  # non_embedded to not present
  def union_change_map({{:non_embedded, type, data}, :not_present}),
    do: %{unchanged: %{type: to_string(type), value: data}}

  def union_change_map({{:non_embedded, type, data}, :removed}),
    do: %{
      from: %{type: to_string(type), value: data}
    }

  # non_embedded to nil
  def union_change_map({{:non_embedded, type, data}, {:non_embedded, nil, nil}}),
    do: %{
      from: %{type: to_string(type), value: data},
      to: nil
    }

  # non_embedded to same non_embedded
  def union_change_map({{:non_embedded, type, data}, {:non_embedded, type, data}}),
    do: %{unchanged: %{type: to_string(type), value: data}}

  # non_embedded to different non_embedded
  def union_change_map({{:non_embedded, data_type, data}, {:non_embedded, value_type, value}}),
    do: %{
      from: %{type: to_string(data_type), value: data},
      to: %{type: to_string(value_type), value: value}
    }

  # non_embedded to embedded
  def union_change_map({{:non_embedded, data_type, data}, {:embedded, value_type, _pk, value}}),
    do: %{
      from: %{type: to_string(data_type), value: data},
      to: %{type: to_string(value_type), created: attribute_changes(%{}, value)}
    }

  # embedded to not present
  def union_change_map({{:embedded, type, _pk, data}, :not_present}),
    do: %{
      unchanged: %{type: to_string(type), value: attribute_changes(data, data)}
    }

  # embedded to removed
  def union_change_map({{:embedded, type, _pk, data}, :removed}),
    do: %{
      from: %{
        type: to_string(type),
        destroyed: attribute_changes(data, nil)
      }
    }

  # embedded to nil
  def union_change_map({{:embedded, type, _pk, data}, {:non_embedded, nil, nil}}),
    do: %{
      from: %{
        type: to_string(type),
        destroyed: attribute_changes(data, nil)
      },
      to: nil
    }

  # embedded to non_embedded
  def union_change_map({{:embedded, data_type, _pk, data}, {:non_embedded, value_type, value}}),
    do: %{
      from: %{
        type: to_string(data_type),
        destroyed: attribute_changes(data, nil)
      },
      to: %{type: to_string(value_type), value: value}
    }

  # embedded to same embedded
  def union_change_map({{:embedded, type, pk, data}, {:embedded, type, pk, data}}),
    do: %{
      unchanged: %{
        type: to_string(type),
        value: attribute_changes(data, data)
      }
    }

  # embedded to updated embedded
  def union_change_map({{:embedded, type, pk, data}, {:embedded, type, pk, value}}),
    do: %{
      updated: %{
        type: to_string(type),
        value: attribute_changes(data, value)
      }
    }

  # embedded to different embedded
  def union_change_map(
        {{:embedded, data_type, _data_pk, data}, {:embedded, value_type, _value_pk, value}}
      ),
      do: %{
        from: %{
          type: to_string(data_type),
          destroyed: attribute_changes(data, nil)
        },
        to: %{type: to_string(value_type), created: attribute_changes(%{}, value)}
      }
end
