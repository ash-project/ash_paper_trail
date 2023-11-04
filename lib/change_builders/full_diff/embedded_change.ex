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
    |> IO.inspect(label: "#{attribute.name} dump_data_value")
    |> embedded_change_map()
  end
end
