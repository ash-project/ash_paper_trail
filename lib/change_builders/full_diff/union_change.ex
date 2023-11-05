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

    %{ from: nil, created: %{type: type, value: %{ ...attributes... } } }
    %{ unchanged: %{type: type, value: %{ ...attributes... } } }
    %{ updated: %{type: type, value: %{ ...attributes... } } }
    %{ from: %{type: type, value: value}, created: %{type: type, value: %{ ...attributes... } }
    %{ destroyed: %{type: type, value: %{ ...attributes... } }, to: nil }
    %{ destroyed: %{type: type, value: %{ ...attributes... } }, created: %{type: type, value: %{ ...attributes... } } }
    %{ destroyed: %{type: type, destroyed: %{ ...attributes... } }, to: %{type: type, value: value } }
  """
  import AshPaperTrail.ChangeBuilders.FullDiff.Helpers

  def build(attribute, changeset) do
    dump_union_data_value(changeset, attribute)
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
    %{"type" => type, "value" => dumped_value} = dump_value(value, attribute)

    if embedded_union?(attribute.type, type) do
      primary_key = primary_keys(value, dumped_value) |> IO.inspect(label: "primary_key")
      {:embedded, type, primary_key, dumped_value}
    else
      {:non_embedded, type, dumped_value}
    end
  end

  # def union_change_map({{_data_present, _data_type, _data}, { _value_present, _value_type, _value}}),

  # Non-present to still no value
  def union_change_map({{:not_present}, {:not_present}}),
    do: %{to: nil}

  # Non-present to nil
  def union_change_map({{:not_present}, {:non_embedded, nil, nil}}),
    do: %{to: nil}

  # Not present to non_embedded
  def union_change_map({{:not_present}, {:non_embedded, type, value}}),
    do: %{to: %{type: to_string(type), value: value}}

  # Not present to embedded
  def union_change_map({{:not_present}, {:embedded, type, _pk, value}}),
    do: %{created: %{type: to_string(type), value: attribute_changes(%{}, value)}}

  # nil unchanged
  def union_change_map({{:non_embedded, nil, nil}, {:not_present}}),
    do: %{unchanged: nil}

  # nil to nil
  def union_change_map({{:non_embedded, nil, nil}, {:non_embedded, nil, nil}}),
    do: %{unchanged: nil}

  # nil to embedded
  def union_change_map({{:non_embedded, nil, nil}, {:embedded, type, _pk, value}}),
    do: %{
      from: nil,
      created: %{type: to_string(type), value: attribute_changes(%{}, value)}
    }

  # nil to non_embedded
  def union_change_map({{:non_embedded, nil, nil}, {:non_embedded, type, value}}),
    do: %{
      from: nil,
      to: %{type: to_string(type), value: value}
    }

  # non_embedded to not present
  def union_change_map({{:non_embedded, type, data}, {:not_present}}),
    do: %{unchanged: %{type: to_string(type), value: data}}

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
      created: %{type: to_string(value_type), value: attribute_changes(%{}, value)}
    }

  # embedded to not present
  def union_change_map({{:embedded, type, _pk, data}, {:not_present}}),
    do: %{
      unchanged: %{type: to_string(type), value: attribute_changes(data, data)}
    }

  # embedded to nil
  def union_change_map({{:embedded, type, _pk, data}, {:non_embedded, nil, nil}}),
    do: %{
      destroyed: %{
        type: to_string(type),
        value: attribute_changes(data, nil)
      },
      to: nil
    }

  # embedded to non_embedded
  def union_change_map({{:embedded, data_type, _pk, data}, {:non_embedded, value_type, value}}),
    do: %{
      destroyed: %{
        type: to_string(data_type),
        value: attribute_changes(data, nil)
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

  # embedded to different embedded
  def union_change_map(
        {{:embedded, data_type, _data_pk, data}, {:embedded, value_type, _value_pk, value}}
      ),
      do: %{
        destroyed: %{
          type: to_string(data_type),
          value: attribute_changes(data, nil)
        },
        created: %{type: to_string(value_type), value: attribute_changes(%{}, value)}
      }

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
