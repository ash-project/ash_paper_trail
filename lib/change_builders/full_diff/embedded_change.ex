# SPDX-FileCopyrightText: 2022 ash_paper_trail contributors <https://github.com/ash-project/ash_paper_trail/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshPaperTrail.ChangeBuilders.FullDiff.EmbeddedChange do
  import AshPaperTrail.ChangeBuilders.FullDiff.Helpers

  @moduledoc """
    A simple attribute change will be represented as a map:

    %{ created: %{ subject: %{to: "subject"} } }
    %{ updated: %{ subject: %{from: "subject", to: "new subject"} } }
    %{ unchanged: %{ subject: %{unchanged: "subject"} } }
    %{ destroyed: %{ subject: %{unchanged: "subject"} } }

  """

  def build(attribute, changeset) do
    dump_data_value(changeset, attribute)
    |> embedded_change_map()
  end

  def dump_data_value(changeset, attribute) do
    data_tuple =
      if changeset.action_type == :create do
        :not_present
      else
        case Ash.Changeset.get_data(changeset, attribute.name) do
          nil ->
            nil

          data ->
            dumped_data = dump_value(data, attribute)
            uid = unique_id(data, dumped_data)
            {uid, dumped_data}
        end
      end

    value_tuple =
      case Ash.Changeset.fetch_change(changeset, attribute.name) do
        {:ok, nil} ->
          nil

        {:ok, value} ->
          dumped_value = dump_value(value, attribute)
          uid = unique_id(value, dumped_value)
          {uid, dumped_value}

        :error ->
          :not_present
      end

    {data_tuple, value_tuple}
  end
end
