defmodule AshPaperTrail.Resource.Changes.CreateNewVersion do
  @moduledoc "Creates a new version whenever a resource is created, deleted, or updated"
  use Ash.Resource.Change

  require Ash.Query
  require Logger

  @impl true
  def change(changeset, _, _) do
    if changeset.action_type in [:create, :destroy] ||
         (changeset.action_type == :update &&
            changeset.action.name in AshPaperTrail.Resource.Info.on_actions(changeset.resource)) do
      create_new_version(changeset)
    else
      changeset
    end
  end

  @impl true
  def atomic(changeset, opts, context) do
    change_tracking_mode = AshPaperTrail.Resource.Info.change_tracking_mode(changeset.resource)

    if change_tracking_mode == :full_diff do
      {:not_atomic, "Cannot perform full_diff change tracking with AshPaperTrail atomically."}
    else
      {:ok, change(changeset, opts, context)}
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

    to_skip =
      Ash.Resource.Info.primary_key(changeset.resource) ++
        AshPaperTrail.Resource.Info.ignore_attributes(changeset.resource)

    attributes_as_attributes =
      AshPaperTrail.Resource.Info.attributes_as_attributes(changeset.resource)

    change_tracking_mode = AshPaperTrail.Resource.Info.change_tracking_mode(changeset.resource)

    belongs_to_actors =
      AshPaperTrail.Resource.Info.belongs_to_actor(changeset.resource)

    actor = changeset.context[:private][:actor]

    resource_attributes =
      changeset.resource
      |> Ash.Resource.Info.attributes()

    {input, private} =
      resource_attributes
      |> Enum.filter(&(&1.name in attributes_as_attributes))
      |> Enum.reduce({%{}, %{}}, &build_inputs(&1, &2, result))

    changes =
      resource_attributes
      |> Enum.reject(&(&1.name in to_skip))
      |> build_changes(change_tracking_mode, changeset, result)

    input =
      Enum.reduce(belongs_to_actors, input, fn belongs_to_actor, input ->
        with true <- is_struct(actor) && actor.__struct__ == belongs_to_actor.destination,
             relationship when not is_nil(relationship) <-
               Ash.Resource.Info.relationship(version_resource, belongs_to_actor.name) do
          primary_key = Map.get(actor, hd(Ash.Resource.Info.primary_key(actor.__struct__)))
          source_attribute = Map.get(relationship, :source_attribute)
          Map.put(input, source_attribute, primary_key)
        else
          _ ->
            input
        end
      end)
      |> Map.merge(%{
        version_source_id: Map.get(result, hd(Ash.Resource.Info.primary_key(changeset.resource))),
        version_action_type: changeset.action.type,
        version_action_name: changeset.action.name,
        changes: changes
      })

    {_, notifications} =
      version_changeset
      |> Ash.Changeset.set_context(%{ash_paper_trail?: true})
      |> Ash.Changeset.for_create(:create, input,
        tenant: changeset.tenant,
        authorize?: authorize?(changeset.domain),
        actor: actor,
        domain: changeset.domain,
        skip_unknown_inputs: Map.keys(input)
      )
      |> Ash.Changeset.force_change_attributes(Map.take(private, version_resource_attributes))
      |> Ash.create!(return_notifications?: true)

    notifications
  end

  defp build_inputs(%{public?: true} = attribute, {input, private}, result) do
    {
      Map.put(
        input,
        attribute.name,
        Map.get(result, attribute.name)
      ),
      private
    }
  end

  defp build_inputs(attribute, {input, private}, result) do
    {input,
     Map.put(
       private,
       attribute.name,
       Map.get(result, attribute.name)
     )}
  end

  defp build_changes(attributes, :changes_only, changeset, result) do
    AshPaperTrail.ChangeBuilders.ChangesOnly.build_changes(attributes, changeset, result)
  end

  defp build_changes(attributes, :snapshot, changeset, result) do
    AshPaperTrail.ChangeBuilders.Snapshot.build_changes(attributes, changeset, result)
  end

  defp build_changes(attributes, :full_diff, changeset, result) do
    AshPaperTrail.ChangeBuilders.FullDiff.build_changes(attributes, changeset, result)
  end

  defp authorize?(domain), do: Ash.Domain.Info.authorize(domain) == :always
end
