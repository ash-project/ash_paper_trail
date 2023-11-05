defmodule AshPaperTrail.ChangeBuilders.FullDiff.SimpleChange do
  @moduledoc """
  A simple attribute change will be represented as a map:

    %{ to: value }
    %{ from: value, to: value }
    %{ unchange: value }
  """
  import AshPaperTrail.ChangeBuilders.FullDiff.Helpers

  def build(attribute, changeset) do
    dump_data_value(changeset, attribute)
    |> attribute_change_map()
  end

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
end
