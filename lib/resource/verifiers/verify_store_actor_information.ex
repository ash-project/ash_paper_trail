defmodule AshPaperTrail.Resource.Verifiers.ValidateBelongsToActor do
  use Spark.Dsl.Verifier

  def verify(dsl_state) do
    store_actor_information = AshPaperTrail.Resource.Info.store_actor_information(dsl_state)

    missing_by_destination =
      store_actor_information
      |> Enum.map(fn %AshPaperTrail.Resource.StoreActorInformation{
                       attributes: attributes,
                       destination: destination
                     } ->
        destination_attributes = Ash.Resource.Info.attribute_names(destination)

        missing =
          Enum.filter(attributes, fn attr ->
            not Enum.member?(destination_attributes, attr)
          end)

        {destination, missing}
      end)
      |> Enum.reject(fn {_destination, missing} -> missing == [] end)

    if missing_by_destination == [] do
      :ok
    else
      {:error,
       %Spark.Error.DslError{
         message: """
         All store_actor_information attributes must exist as attributes on the destination resource.
         #{format_missing_by_destination(missing_by_destination)}
         """,
         module: Spark.Dsl.Verifier.get_persisted(dsl_state, :module)
       }}
    end
  end

  defp format_missing_by_destination(missing_by_destination) do
    missing_by_destination
    |> Enum.map(fn {destination, missing_attrs} ->
      """
      Destination: #{inspect(destination)}
      Missing Attributes: #{Enum.map_join(missing_attrs, ", ", &inspect/1)}
      """
    end)
  end
end
