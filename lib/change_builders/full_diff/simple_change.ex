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
end
