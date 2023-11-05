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
    |> IO.inspect(label: "dump_data_value")
    |> embedded_change_map()
  end

  def dump_data_value(changeset, attribute) do
    data_tuple =
      if changeset.action_type == :create do
        {:not_present}
      else
        case Ash.Changeset.get_data(changeset, attribute.name) do
          nil ->
            {nil}

          data ->
            dumped_data = dump_value(data, attribute)
            pk = primary_keys(data, dumped_data)
            {pk, dumped_data}
        end
      end

    value_tuple =
      case Ash.Changeset.fetch_change(changeset, attribute.name) do
        {:ok, nil} ->
          {nil}

        {:ok, value} ->
          dumped_value = dump_value(value, attribute)
          pk = primary_keys(value, dumped_value)
          {pk, dumped_value}

        :error ->
          {:not_present}
      end

    {data_tuple, value_tuple}
  end

  # Builds a simple change map based on the given values.
  #
  # change_map({data_present, data, value_present, value})

  defp embedded_change_map({{:not_present}, {:not_present}}), do: %{to: nil}
  defp embedded_change_map({{:not_present}, {nil}}), do: %{to: nil}

  defp embedded_change_map({{:not_present}, {_pk, %{} = value}}),
    do: %{created: attribute_changes(%{}, value)}

  defp embedded_change_map({{nil}, {:not_present}}), do: %{unchanged: nil}
  defp embedded_change_map({{nil}, {nil}}), do: %{unchanged: nil}

  defp embedded_change_map({{nil}, {_pk, %{} = value}}),
    do: %{created: attribute_changes(%{}, value), from: nil}

  defp embedded_change_map({{_pk, data}, {:not_present}}),
    do: %{unchanged: attribute_changes(data, data)}

  defp embedded_change_map({{_pk, data}, {nil}}),
    do: %{destroyed: attribute_changes(data, nil), to: nil}

  defp embedded_change_map({{pk, data}, {pk, data}}),
    do: %{unchanged: attribute_changes(data, data)}

  defp embedded_change_map({{pk, data}, {pk, value}}),
    do: %{updated: attribute_changes(data, value)}

  defp embedded_change_map({{_data_pk, data}, {_value_pk, value}}),
    do: %{destroyed: attribute_changes(data, nil), created: attribute_changes(%{}, value)}
end
