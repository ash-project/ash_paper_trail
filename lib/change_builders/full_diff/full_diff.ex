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
    EmbeddedArrayChange, UnionArrayChange
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
    IO.inspect(
      "================================== Starting Full Diff =================================="
    )

    Enum.reduce(attributes, %{}, fn attribute, changes ->
      Map.put(
        changes,
        attribute.name,
        build_attribute_change(attribute, changeset)
      )
    end)
  end

  defp build_attribute_change(attribute, changeset) do
    {array, type} =
      case attribute do
        %{type: {:array, attr_type}} -> {true, attr_type}
        %{type: attr_type} -> {false, attr_type}
      end

    cond do
      array && is_union?(type) ->
        UnionArrayChange.build(attribute, changeset)

      array && is_embedded?(type) ->
        EmbeddedArrayChange.build(attribute, changeset)

      is_union?(attribute.type) ->
        UnionChange.build(attribute, changeset)

      is_embedded?(attribute.type) ->
        EmbeddedChange.build(attribute, changeset)

      true ->
        SimpleChange.build(attribute, changeset)
    end
  end
end
