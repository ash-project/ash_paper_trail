# SPDX-FileCopyrightText: 2022 ash_paper_trail contributors <https://github.com/ash-project/ash_paper_trail/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshPaperTrail.ChangeBuilders.FullDiff.Helpers do
  @moduledoc """
  Misc helpers for building a full diff of a changeset.
  """

  def dump_value(value, attribute, sensitive_mode \\ :display)

  def dump_value(%Ash.ForbiddenField{}, _attribute, _sensitive_mode), do: nil

  def dump_value(nil, _attribute, _sensitive_mode), do: nil

  def dump_value(values, %{type: {:array, attr_type}} = attribute, sensitive_mode) do
    item_constraints = attribute.constraints[:items]

    # This is a work around for a bug in Ash.Type.dump_to_embedded/3
    Enum.map(values, fn
      %Ash.ForbiddenField{} ->
        nil

      value ->
        {:ok, dumped_value} = Ash.Type.dump_to_embedded(attr_type, value, item_constraints)
        redact_dumped_value(dumped_value, attr_type, item_constraints || [], sensitive_mode)
    end)
  end

  def dump_value(value, attribute, sensitive_mode) do
    {:ok, dumped_value} = Ash.Type.dump_to_embedded(attribute.type, value, attribute.constraints)
    redact_dumped_value(dumped_value, attribute.type, attribute.constraints, sensitive_mode)
  end

  def sensitive_mode(changeset) do
    changeset.context[:sensitive_attributes] ||
      AshPaperTrail.Resource.Info.sensitive_attributes(changeset.resource)
  end

  def redact_dumped_value(value, type, constraints, sensitive_mode \\ :display)

  def redact_dumped_value(value, _type, _constraints, :display), do: value

  def redact_dumped_value(nil, _type, _constraints, _mode), do: nil

  def redact_dumped_value(values, {:array, item_type}, constraints, mode) when is_list(values) do
    item_constraints = (constraints || [])[:items] || []
    Enum.map(values, &redact_dumped_value(&1, item_type, item_constraints, mode))
  end

  def redact_dumped_value(%{} = value, type, constraints, mode) do
    cond do
      union?(type) -> redact_union(value, type, constraints, mode)
      embedded_resource_module(type) -> redact_embedded(value, type, mode)
      true -> value
    end
  end

  def redact_dumped_value(value, _type, _constraints, _mode), do: value

  defp redact_embedded(%{} = dumped, type, mode) do
    case embedded_resource_module(type) do
      nil ->
        dumped

      resource ->
        resource
        |> Ash.Resource.Info.attributes()
        |> Enum.reduce(dumped, &redact_embedded_attribute(&2, &1, mode))
    end
  end

  defp redact_embedded_attribute(dumped, attribute, mode) do
    case fetch_dumped_key(dumped, attribute.name) do
      :error ->
        dumped

      {:ok, key, value} ->
        cond do
          attribute.sensitive? and mode == :ignore ->
            Map.delete(dumped, key)

          attribute.sensitive? ->
            Map.put(dumped, key, "REDACTED")

          true ->
            Map.put(
              dumped,
              key,
              redact_dumped_value(value, attribute.type, attribute.constraints, mode)
            )
        end
    end
  end

  defp fetch_dumped_key(map, name) do
    cond do
      Map.has_key?(map, name) -> {:ok, name, Map.get(map, name)}
      Map.has_key?(map, to_string(name)) -> {:ok, to_string(name), Map.get(map, to_string(name))}
      true -> :error
    end
  end

  defp redact_union(%{"value" => value} = dumped, type, constraints, mode) do
    case union_subtype(type, constraints, Map.get(dumped, "type")) do
      {subtype_type, subtype_constraints} ->
        Map.put(
          dumped,
          "value",
          redact_dumped_value(value, subtype_type, subtype_constraints, mode)
        )

      nil ->
        dumped
    end
  end

  defp redact_union(dumped, _type, _constraints, _mode), do: dumped

  defp union_subtype(type, constraints, type_name) when is_binary(type_name) do
    types =
      cond do
        is_list(constraints) and is_list(constraints[:types]) ->
          constraints[:types]

        is_atom(type) and :erlang.function_exported(type, :subtype_constraints, 0) ->
          type.subtype_constraints()[:types] || []

        true ->
          []
      end

    Enum.find_value(types, fn {name, config} ->
      if to_string(name) == type_name do
        {config[:type], config[:constraints] || []}
      end
    end)
  end

  defp union_subtype(_type, _constraints, _type_name), do: nil

  defp embedded_resource_module(type) do
    cond do
      Ash.Type.NewType.new_type?(type) ->
        embedded_resource_module(Ash.Type.NewType.subtype_of(type))

      is_atom(type) and Ash.Resource.Info.resource?(type) ->
        type

      true ->
        nil
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
