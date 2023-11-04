defmodule AshPaperTrail.ChangeBuilders.FullDiff.UnionChange do
  @moduledoc """
    A non-embedded union attribute change will be represented as a map:

    %{ to: nil }
    %{ to: %{value: value, type: type } }
    %{ from: %{value: value, type: type }, to: %{value: value, type: type } }
    %{ unchanged: %{value: value, type: type } }

    If the from & to are embedded resources with the same primary key
    then, we'll have consider it changed and represent it as:

    %{ changed: %{type: type, updated: %{ ...attributes... } } }

    If the union value is an embedded resource the `value` key will be replaced with
    created, unchanged, updated, destroyed.

    %{ from: nil, to: %{type: type, created: %{ ...attributes... } } }
    %{ unchanged: %{type: type, unchanged: %{ ...attributes... } } }
    %{ updated: %{type: type, updated: %{ ...attributes... } } }
    %{ from: %{type: type, value: value}, to: %{type: type, created: %{ ...attributes... } }
    %{ from: %{type: type, destroyed: %{ ...attributes... } }, to: nil }
    %{ from: %{type: type, destroyed: %{ ...attributes... } }, to: %{type: type, created: %{ ...attributes... } } }
    %{ from: %{type: type, destroyed: %{ ...attributes... } }, to: %{type: type, value: value } }
  """
  import AshPaperTrail.ChangeBuilders.FullDiff.Helpers

  def build(attribute, changeset) do
    dump_union_data_value(changeset, attribute)
    |> IO.inspect(label: "#{attribute.name} dump_union_data_value")
    |> union_change_map()
  end

  # Returns two tuples for the data and value.  Each tuple contains:
  # { present_or_embeddedness, type, value }
  defp dump_union_data_value(changeset, attribute) do
    data_tuple =
      if changeset.action_type == :create do
        {:not_present}
      else
        data = Ash.Changeset.get_data(changeset, attribute.name)
        dump_union_type_value(data, attribute)
      end

    value_tuple =
      case Ash.Changeset.fetch_change(changeset, attribute.name) do
        {:ok, value} ->
          dump_union_type_value(value, attribute)

        :error ->
          {:not_present}
      end

    {data_tuple, value_tuple}
  end

  # Returns a tuple {embedded, type, value}
  def dump_union_type_value(nil, _attribute), do: {:non_embedded, nil, nil}

  def dump_union_type_value(value, attribute) do
    %{"type" => type, "value" => value} = dump_value(value, attribute)

    if embedded_union?(attribute.type, type) do
      {:embedded, type, value}
    else
      {:non_embedded, type, value}
    end
  end

  # def union_change_map({{_data_present, _data_type, _data}, { _value_present, _value_type, _value}}),

  def union_change_map({{:not_present}, {:non_embedded, type, value}}),
  do: %{to: %{type: to_string(type), value: value}}

  def union_change_map({{:non_embedded, nil, nil}, {:not_present}}),
  do: %{unchanged: nil}

  def union_change_map({{:non_embedded, type, data}, {:not_present}}),
    do: %{unchanged: %{type: to_string(type), value: data}}

  def union_change_map({{:non_embedded, data_type, data}, {:non_embedded, value_type, value}}),
    do: %{
      from: %{type: to_string(data_type), value: data},
      to: %{type: to_string(value_type), value: value}
    }

  def union_change_map({data, value}),
    do: %{data: data, value: value}

  # def union_change_map(
  #       data_present,
  #       false,
  #       _data_type,
  #       data,
  #       value_present,
  #       false,
  #       _value_type,
  #       value
  #     ),
  #     do: attribute_change_map({data_present, data, value_present, value})

  # def union_change_map(
  #       _data_present,
  #       _data_embedded,
  #       _data_type,
  #       nil,
  #       _value_present,
  #       _value_embedded,
  #       _value_type,
  #       nil
  #     ),
  #     do: %{unchanged: nil}

  # def union_change_map(
  #       true = _data_present,
  #       _data_embedded,
  #       _data_type,
  #       nil,
  #       true = _value_present,
  #       true = _value_embedded,
  #       value_type,
  #       %{} = value
  #     ),
  #     do: %{
  #       created: build_embedded_attribute_changes(%{}, value),
  #       from: nil,
  #       type: %{to: to_string(value_type)}
  #     }

  # def union_change_map(
  #       true = _data_present,
  #       false = _data_embedded,
  #       _data_type,
  #       data,
  #       true = _value_present,
  #       true = _value_embedded,
  #       value_type,
  #       %{} = value
  #     ),
  #     do: %{
  #       created: build_embedded_attribute_changes(%{}, value),
  #       type: %{to: to_string(value_type)},
  #       from: %{type: to_string(data[:type]), value: data[:value]}
  #     }

  # def union_change_map(
  #       false = _data_present,
  #       _data_embedded,
  #       _data_type,
  #       nil,
  #       _value_present,
  #       _value_embedded,
  #       value_type,
  #       %{} = value
  #     ),
  #     do: %{
  #       created: build_embedded_attribute_changes(%{}, value),
  #       type: %{to: to_string(value_type)}
  #     }

  # def union_change_map(
  #       _data_present,
  #       _data_embedded,
  #       _data_type,
  #       %{} = data,
  #       _value_present,
  #       _value_embedded,
  #       _value_type,
  #       nil
  #     ),
  #     do: %{destroyed: build_embedded_attribute_changes(data, %{})}

  # def union_change_map(
  #       _data_present,
  #       _data_embedded,
  #       data_type,
  #       %{} = data,
  #       _value_present,
  #       _value_embedded,
  #       data_type,
  #       data
  #     ),
  #     do: %{
  #       unchanged: build_embedded_attribute_changes(data, data),
  #       type: %{unchanged: to_string(data_type)}
  #     }

  # def union_change_map(
  #       _data_present,
  #       _data_embedded,
  #       data_type,
  #       %{} = data,
  #       _value_present,
  #       _value_embedded,
  #       data_type,
  #       %{} = value
  #     ),
  #     do: %{
  #       updated: build_embedded_attribute_changes(data, value),
  #       type: %{unchanged: to_string(data_type)}
  #     }

  # def union_change_map(
  #       true,
  #       _data_embedded,
  #       data_type,
  #       %{} = data,
  #       _value_present,
  #       true,
  #       value_type,
  #       %{} = value
  #     ),
  #     do: %{
  #       created: build_embedded_attribute_changes(%{}, value),
  #       destroyed: build_embedded_attribute_changes(data, %{}),
  #       type: %{from: to_string(data_type), to: to_string(value_type)}
  #     }

  # def union_change_map(
  #       true,
  #       _data_embedded,
  #       data_type,
  #       %{} = data,
  #       _value_present,
  #       false,
  #       _value_type,
  #       %{} = value
  #     ),
  #     do: %{
  #       to: %{type: to_string(value[:type]), value: value[:value]},
  #       destroyed: build_embedded_attribute_changes(data, %{}),
  #       type: %{from: to_string(data_type)}
  #     }

  defp embedded_union?(type, subtype) do
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
end
