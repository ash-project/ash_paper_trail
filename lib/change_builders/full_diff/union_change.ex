defmodule AshPaperTrail.ChangeBuilders.FullDiff.UnionChange do
  import AshPaperTrail.ChangeBuilders.FullDiff.Helpers

  # A non-embedded union attribute change will be represented as a map:
  #
  #   %{ to: %{value: value, type: type } }
  #   %{ from: %{value: value, type: type }, to: %{value: value, type: type } }
  #   %{ unchanged: %{value: value, type: type } }
  #
  # While a embedded union attribute change will be represented as:
  #
  #   %{ to: nil }
  #   %{ created: %{ attr: %{to: ""}, ...}, type: "..." }
  #   %{ updated: %{ attr: %{to: ""}, ...}, type: "..." }
  #   %{ destroyed: %{ attr: %{to: ""}, ...}, type: "..." }
  def build(attribute, changeset) do
    {data_present, data_embedded, dumped_data_type, dumped_data} =
      if changeset.action_type == :create do
        {false, false, nil, nil}
      else
        data = Ash.Changeset.get_data(changeset, attribute.name)

        case dump_union_value(data, attribute) do
          {:non_embedded, _, dumped_data} ->
            {true, false, nil, dumped_data}

          {:embedded, dumped_data_type, dumped_data_value} ->
            {true, true, dumped_data_type, dumped_data_value}
        end
      end

    {value_present, value_embedded, dumped_value_type, dumped_value} =
      case Ash.Changeset.fetch_change(changeset, attribute.name) do
        {:ok, value} ->
          case dump_union_value(value, attribute) do
            {:non_embedded, _, dumped_value} ->
              {true, false, nil, dumped_value}

            {:embedded, dumped_value_type, dumped_value} ->
              {true, true, dumped_value_type, dumped_value}
          end

        :error ->
          {data_present, data_embedded, dumped_data_type, dumped_data}
      end

    # IO.inspect([data_present, data_embedded, dumped_data_type, dumped_data, value_present, value_embedded, dumped_value_type, dumped_value], label: "build_embedded_union_changes")

    build_embedded_union_changes(
      data_present,
      data_embedded,
      dumped_data_type,
      dumped_data,
      value_present,
      value_embedded,
      dumped_value_type,
      dumped_value
    )
  end


end
