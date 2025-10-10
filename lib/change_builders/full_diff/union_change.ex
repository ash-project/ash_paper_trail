# SPDX-FileCopyrightText: 2020 Zach Daniel
#
# SPDX-License-Identifier: MIT

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
        :not_present
      else
        data = Ash.Changeset.get_data(changeset, attribute.name)
        dump_union_type_value(data, attribute)
      end

    value_tuple =
      case Ash.Changeset.fetch_change(changeset, attribute.name) do
        {:ok, value} ->
          dump_union_type_value(value, attribute)

        :error ->
          :not_present
      end

    {data_tuple, value_tuple}
  end

  # Returns a tuple {embedded, type, value}
  def dump_union_type_value(nil, _attribute), do: {:non_embedded, nil, nil}

  def dump_union_type_value(value, attribute) do
    %{"type" => type, "value" => dumped_value} = dump_value(value, attribute)

    if embedded_union?(attribute.type, type) do
      uid = unique_id(value, dumped_value)
      {:embedded, type, uid, dumped_value}
    else
      {:non_embedded, type, dumped_value}
    end
  end
end
