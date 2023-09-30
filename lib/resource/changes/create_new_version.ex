defmodule AshPaperTrail.Resource.Changes.CreateNewVersion do
  @moduledoc "Creates a new version whenever a resource is created, deleted, or updated"
  use Ash.Resource.Change

  require Ash.Query
  require Logger

  def change(changeset, _, _) do
    if changeset.action_type in [:create, :destroy] ||
         (changeset.action_type == :update &&
            changeset.action.name in AshPaperTrail.Resource.Info.on_actions(changeset.resource)) do
      create_new_version(changeset)
    else
      changeset
    end
  end

  defp create_new_version(changeset) do
    Ash.Changeset.after_action(changeset, fn changeset, result ->
      if changeset.action_type in [:create, :destroy] ||
           (changeset.action_type == :update && changeset.context.changed?) do
        {:ok, result, build_notifications(changeset, result)}
      else
        {:ok, result}
      end
    end)
  end

  defp build_notifications(changeset, result) do
    version_resource = AshPaperTrail.Resource.Info.version_resource(changeset.resource)

    version_resource_attributes =
      version_resource |> Ash.Resource.Info.attributes() |> Enum.map(& &1.name)

    version_changeset = Ash.Changeset.new(version_resource)

    to_skip = AshPaperTrail.Resource.Info.ignore_attributes(changeset.resource)

    attributes_as_attributes =
      AshPaperTrail.Resource.Info.attributes_as_attributes(changeset.resource)

    change_tracking_mode = AshPaperTrail.Resource.Info.change_tracking_mode(changeset.resource)

    resource_attributes =
      changeset.resource
      |> Ash.Resource.Info.attributes()

    {input, private} =
      resource_attributes
      |> Enum.filter(&(&1.name in attributes_as_attributes))
      |> Enum.reduce({%{}, %{}}, &build_inputs(changeset, &1, &2))

    changes =
      resource_attributes
      |> Enum.reject(&(&1.name in to_skip))
      |> Enum.reduce(%{}, &build_changes(change_tracking_mode, changeset, &1, &2))

    input =
      Map.merge(input, %{
        version_source_id: Map.get(result, hd(Ash.Resource.Info.primary_key(changeset.resource))),
        version_action_type: changeset.action.type,
        version_action_name: changeset.action.name,
        changes: changes
      })

    {_, notifications} =
      version_changeset
      |> Ash.Changeset.for_create(:create, input,
        tenant: changeset.tenant,
        authorize?: false,
        actor: changeset.context[:private][:actor]
      )
      |> Ash.Changeset.force_change_attributes(Map.take(private, version_resource_attributes))
      |> changeset.api.create!(return_notifications?: true)

    notifications
  end

  defp build_inputs(
         changeset,
         %{private?: true} = attribute,
         {input, private}
       ) do
    {input,
     Map.put(
       private,
       attribute.name,
       Ash.Changeset.get_attribute(changeset, attribute.name)
     )}
  end

  defp build_inputs(changeset, attribute, {input, private}) do
    {
      Map.put(
        input,
        attribute.name,
        Ash.Changeset.get_attribute(changeset, attribute.name)
      ),
      private
    }
  end

  defp build_changes(:snapshot, changeset, attribute, changes) do
    value = Ash.Changeset.get_attribute(changeset, attribute.name)
    {:ok, dumped_value} = Ash.Type.dump_to_embedded(attribute.type, value, [])
    Map.put(changes, attribute.name, dumped_value)
  end

  defp build_changes(:changes_only, changeset, attribute, changes) do
    if Ash.Changeset.changing_attribute?(changeset, attribute.name) do
      value = Ash.Changeset.get_attribute(changeset, attribute.name)
      {:ok, dumped_value} = Ash.Type.dump_to_embedded(attribute.type, value, [])
      Map.put(changes, attribute.name, dumped_value)
    else
      changes
    end
  end

  defp build_changes(:full_diff, %{action: %{type: :create}} = changeset, attribute, changes) do
    case Ash.Changeset.fetch_change(changeset, attribute.name) do
      {:ok, value} ->
        Map.put(changes, attribute.name, %{to: dump_value(value, attribute)})

      :error ->
        Map.put(changes, attribute.name, %{to: nil})
    end
  end

  defp build_changes(:full_diff, changeset, attribute, changes) do
    dumped_data = Ash.Changeset.get_data(changeset, attribute.name) |> dump_value(attribute)

    if Ash.Type.embedded_type?(attribute.type) do
      case Ash.Changeset.fetch_change(changeset, attribute.name) do
        {:ok, value} ->
          Map.put(
            changes,
            attribute.name,
            build_map_changes(dumped_data, dump_value(value, attribute))
          )

        :error ->
          Map.put(changes, attribute.name, %{unchanged: dumped_data})
      end
    else
      case Ash.Changeset.fetch_change(changeset, attribute.name) do
        {:ok, value} ->
          Map.put(changes, attribute.name, %{from: dumped_data, to: dump_value(value, attribute)})

        :error ->
          Map.put(changes, attribute.name, %{unchanged: dumped_data})
      end
    end
  end

  defp build_map_changes(nil, value) do
    %{create: dump_map_changes(%{}, value)}
  end

  defp build_map_changes(data, nil) do
    %{destroy: dump_map_changes(data, %{})}
  end

  defp build_map_changes(data, value) do
    %{update: dump_map_changes(data, value)}
  end

  defp dump_map_changes(%{} = from_map, %{} = to_map) do
    keys = Map.keys(from_map) ++ Map.keys(to_map)

    for key <- keys,
        into: %{},
        do:
          {key,
           dump_map_change_value(
             Map.has_key?(from_map, key),
             Map.get(from_map, key),
             Map.has_key?(to_map, key),
             Map.get(to_map, key)
           )}
  end

  defp dump_map_change_value(false, _from, true, to), do: %{to: to}
  defp dump_map_change_value(true, from, false, _to), do: %{from: from}
  defp dump_map_change_value(true, from, true, from), do: %{unchanged: from}
  defp dump_map_change_value(true, from, true, to), do: %{from: from, to: to}

  defp dump_value(nil, _attribute), do: nil

  defp dump_value(value, attribute) do
    {:ok, dumped_value} = Ash.Type.dump_to_embedded(attribute.type, value, [])
    dumped_value
  end
end
