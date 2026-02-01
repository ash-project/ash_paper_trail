# SPDX-FileCopyrightText: 2022 ash_paper_trail contributors <https://github.com/ash-project/ash_paper_trail/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshPaperTrail.ChangeBuilders.ChangesOnly do
  @moduledoc false
  def build_changes(attributes, changeset, result) do
    Enum.reduce(attributes, %{}, &build_attribute_change(&1, changeset, result, &2))
  end

  def build_attribute_change(attribute, changeset, result, changes) do
    if Ash.Changeset.changing_attribute?(changeset, attribute.name) do
      value = Map.get(result, attribute.name)

      {:ok, dumped_value} =
        Ash.Type.dump_to_embedded(attribute.type, value, attribute.constraints)

      Map.put(changes, attribute.name, dumped_value)
    else
      changes
    end
  end
end
