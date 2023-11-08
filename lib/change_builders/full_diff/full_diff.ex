defmodule AshPaperTrail.ChangeBuilders.FullDiff do
  @moduledoc """
    Builds a diff of the changeset that is both fairly easy read and includes a complete
    representation of the changes mades.
  """

  import AshPaperTrail.ChangeBuilders.FullDiff.Helpers

  alias AshPaperTrail.ChangeBuilders.FullDiff.{
    SimpleChange,
    EmbeddedChange,
    UnionChange,
    ListChange
  }

  @doc """
    Return a map of the changes made with a key for each attribute and a value
    that is a map representing each change.  The structure of map representing the
    each change comes in multiple:  simple/native, embedded, union, and array of embedded and array of unions.

    %{
      subject: %{ from: "subject", to: "new subject" },
      body: { unchanged: "body" }
    }

  """
  def build_changes(attributes, changeset) do
    Enum.reduce(attributes, %{}, fn attribute, changes ->
      Map.put(
        changes,
        attribute.name,
        build_attribute_change(attribute, changeset)
      )
    end)
  end

  defp build_attribute_change(%{type: {:array, _}} = attribute, changeset) do
    ListChange.build(attribute, changeset)
  end

  defp build_attribute_change(attribute, changeset) do
    cond do
      is_union?(attribute.type) ->
        UnionChange.build(attribute, changeset)

      is_embedded?(attribute.type) ->
        EmbeddedChange.build(attribute, changeset)

      true ->
        SimpleChange.build(attribute, changeset)
    end
  end
end
