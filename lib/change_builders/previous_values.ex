# SPDX-FileCopyrightText: 2022 ash_paper_trail contributors <https://github.com/ash-project/ash_paper_trail/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshPaperTrail.ChangeBuilders.PreviousValues do
  @moduledoc false
  # Stores the previous value of each attribute that changed. Nothing is stored on create,
  # as there is no previous version. Designed for temporal resources, where the new values
  # are on the version row itself.
  alias AshPaperTrail.ChangeBuilders.FullDiff.Helpers

  def build_changes(_attributes, %{action_type: :create}, _result), do: %{}

  def build_changes(attributes, changeset, _result) do
    sensitive_mode = Helpers.sensitive_mode(changeset)

    Enum.reduce(attributes, %{}, fn attribute, changes ->
      if Ash.Changeset.changing_attribute?(changeset, attribute.name) do
        value = Map.get(changeset.data, attribute.name)

        {:ok, dumped_value} =
          Ash.Type.dump_to_embedded(attribute.type, value, attribute.constraints)

        dumped_value =
          Helpers.redact_dumped_value(
            dumped_value,
            attribute.type,
            attribute.constraints,
            sensitive_mode
          )

        Map.put(changes, attribute.name, dumped_value)
      else
        changes
      end
    end)
  end
end
