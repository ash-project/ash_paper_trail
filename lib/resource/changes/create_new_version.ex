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
      |> Enum.filter(
        &(change_tracking_mode == :snapshot ||
            Ash.Changeset.changing_attribute?(changeset, &1.name))
      )
      |> Enum.reduce(%{}, &build_changes(changeset, &1, &2))

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

  defp build_changes(changeset, attribute, changes) do
    value = Ash.Changeset.get_attribute(changeset, attribute.name)
    {:ok, dumped_value} = Ash.Type.dump_to_embedded(attribute.type, value, [])
    Map.put(changes, attribute.name, dumped_value)
  end
end
