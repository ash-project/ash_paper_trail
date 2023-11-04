defmodule AshPaperTrail.ChangeBuilders.FullDiff.Helpers do
  @moduledoc """
  Misc helpers for building a full diff of a changeset.
  """

  def dump_data_value(changeset, attribute) do
    {data_present, dumped_data} =
      if changeset.action_type == :create do
        {false, nil}
      else
        {true, Ash.Changeset.get_data(changeset, attribute.name) |> dump_value(attribute)}
      end

    {value_present, dumped_value} =
      case Ash.Changeset.fetch_change(changeset, attribute.name) do
        {:ok, value} ->
          {true, dump_value(value, attribute)}

        :error ->
          {false, nil}
      end

    {data_present, dumped_data, value_present, dumped_value}
  end

  def dump_value(nil, _attribute), do: nil

  def dump_value(value, attribute) do
    {:ok, dumped_value} = Ash.Type.dump_to_embedded(attribute.type, value, attribute.constraints)
    dumped_value
  end

  @doc """
  Builds a simple change map based on the given values.

  attribute_change_map({data_present, data, value_present, value})
  """
  def attribute_change_map({false, _data, _, value}), do: %{to: value}
  def attribute_change_map({true, data, false, _}), do: %{unchanged: data}
  def attribute_change_map({true, data, true, data}), do: %{unchanged: data}
  def attribute_change_map({true, data, true, value}), do: %{from: data, to: value}

  def is_union?(type) do
    type == Ash.Type.Union or
      (Ash.Type.NewType.new_type?(type) && Ash.Type.NewType.subtype_of(type) == Ash.Type.Union)
  end

  def is_embedded?(type), do: Ash.Type.embedded_type?(type)

  def build_embedded_union_changes(
        data_present,
        false,
        _data_type,
        data,
        value_present,
        false,
        _value_type,
        value
      ),
      do: attribute_change_map({data_present, data, value_present, value})

  def build_embedded_union_changes(
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

  def build_embedded_union_changes(
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

  def build_embedded_union_changes(
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

  def build_embedded_union_changes(
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

  def build_embedded_union_changes(
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

  def build_embedded_union_changes(
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

  def build_embedded_union_changes(
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

  def build_embedded_union_changes(
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

  def build_embedded_union_changes(
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

  def build_embedded_attribute_changes(%{} = from_map, %{} = to_map) do
    keys = Map.keys(from_map) ++ Map.keys(to_map)

    for key <- keys,
        into: %{},
        do:
          {key,
           attribute_change_map({
             Map.has_key?(from_map, key),
             Map.get(from_map, key),
             Map.has_key?(to_map, key),
             Map.get(to_map, key)
           })}
  end

  def dump_union_value(nil, _attribute), do: {:non_embedded, nil, nil}

  def dump_union_value(values, attribute) when is_list(values) do
    {:array, type} = attribute.type
    constraints = attribute.constraints[:items]

    values
    |> Enum.map(fn value ->
      {:ok, dumped_value} = Ash.Type.dump_to_embedded(type, value, constraints)
      dumped_value
    end)
    |> Enum.map(fn union_value ->
      if is_embedded_union?(attribute.type, union_value["type"]) do
        {:embedded, union_value["type"], union_value["value"]}
      else
        {:non_embedded, union_value["type"],
         %{value: union_value["value"], type: to_string(union_value["type"])}}
      end
    end)
  end

  def dump_union_value(value, attribute) do
    union_value = dump_value(value, attribute)

    if is_embedded_union?(attribute.type, union_value["type"]) do
      {:embedded, union_value["type"], union_value["value"]}
    else
      {:non_embedded, union_value["type"],
       %{value: union_value["value"], type: to_string(union_value["type"])}}
    end
  end

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

  @doc """
  Builds a simple change map based on the given values.

  change_map({data_present, data, value_present, value})
  """

  def embedded_change_map({false, _data, false, _value}), do: %{to: nil}
  def embedded_change_map({true, nil, _, nil}), do: %{unchanged: nil}

  def embedded_change_map({false, _data, _, %{} = value}),
    do: %{created: attribute_changes(%{}, value)}

  def embedded_change_map({true, nil, _, %{} = value}),
    do: %{created: attribute_changes(%{}, value), from: nil}

  def embedded_change_map({true, data, false, _value}),
    do: %{unchanged: attribute_changes(data, data)}

  def embedded_change_map({true, data, true, data}),
    do: %{unchanged: attribute_changes(data, data)}

  def embedded_change_map({true, data, true, nil}),
    do: %{destroyed: attribute_changes(data, nil), to: nil}

  def embedded_change_map({true, data, true, value}),
    do: %{updated: attribute_changes(data, value)}

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
      |>MapSet.new()
      |>MapSet.union(keys)
    end)
  end

  defp map_key(%{} = map, key) do
    {Map.has_key?(map, key), Map.get(map, key)}
  end
end
