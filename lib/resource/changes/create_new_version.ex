defmodule AshPaperTrail.Resource.Changes.CreateNewVersion do
  @moduledoc "Creates a new version whenever a resource is created, deleted, or updated"
  use Ash.Resource.Change

  require Ash.Query

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
      notifications =
        if changeset.action_type in [:create, :destroy] ||
             (changeset.action_type == :update && changeset.context.changed?) do
          version_resource = AshPaperTrail.Resource.Info.version_resource(changeset.resource)

          version_resource_attributes =
            version_resource |> Ash.Resource.Info.attributes() |> Enum.map(& &1.name)

          version_changeset = Ash.Changeset.new(version_resource)

          to_skip = AshPaperTrail.Resource.Info.ignore_attributes(changeset.resource)

          {input, private, changes} =
            changeset.resource
            |> Ash.Resource.Info.attributes()
            |> Enum.reject(&(&1.name in to_skip))
            |> Enum.reduce({%{}, %{}, %{}}, fn attribute, {input, private, changes} ->
              if attribute.private? do
                {input,
                 Map.put(
                   private,
                   attribute.name,
                   Ash.Changeset.get_attribute(changeset, attribute.name)
                 ),
                 Map.put(
                   changes,
                   attribute.name,
                   Ash.Changeset.get_attribute(changeset, attribute.name)
                 )}
              else
                {Map.put(
                   input,
                   attribute.name,
                   Ash.Changeset.get_attribute(changeset, attribute.name)
                 ), private,
                 Map.put(
                   changes,
                   attribute.name,
                   Ash.Changeset.get_attribute(changeset, attribute.name)
                 )}
              end
            end)

          input =
            Map.merge(input, %{
              version_source_id:
                Map.get(result, hd(Ash.Resource.Info.primary_key(changeset.resource))),
              version_action_type: changeset.action.type,
              changes: changes
            })

          {_, notifications} =
            version_changeset
            |> Ash.Changeset.for_create(:create, input,
              tenant: changeset.tenant,
              authorize?: false,
              actor: changeset.context[:private][:actor]
            )
            |> Ash.Changeset.force_change_attributes(
              Map.take(private, version_resource_attributes)
            )
            |> changeset.api.create!(return_notifications?: true)

          notifications
        else
          []
        end

      {:ok, result, notifications}
    end)
  end
end
