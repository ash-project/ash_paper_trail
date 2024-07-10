defmodule AshPaperTrail.ChangeBuilders.Snapshot do
  @moduledoc false
  def build_changes(attributes, changeset, result) do
    Enum.reduce(attributes, %{}, &build_attribute_change(&1, changeset, result, &2))
  end

  def build_attribute_change(attribute, _changeset, result, changes) do
    value = Map.get(result, attribute.name)
    {:ok, dumped_value} = Ash.Type.dump_to_embedded(attribute.type, value, attribute.constraints)
    Map.put(changes, attribute.name, dumped_value)
  end
end
