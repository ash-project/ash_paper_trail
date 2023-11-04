defmodule AshPaperTrail.ChangeBuilders.ChangesOnly do
  def build_changes(attributes, changeset) do
    Enum.reduce(attributes, %{}, &build_attribute_change(&1, changeset, &2))
  end

  def build_attribute_change(attribute, changeset, changes) do
    if Ash.Changeset.changing_attribute?(changeset, attribute.name) do
      value = Ash.Changeset.get_attribute(changeset, attribute.name)
      {:ok, dumped_value} = Ash.Type.dump_to_embedded(attribute.type, value, [])
      Map.put(changes, attribute.name, dumped_value)
    else
      changes
    end
  end
end
