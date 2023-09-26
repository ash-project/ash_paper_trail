defmodule AshPaperTrail do
  @moduledoc """
  Documentation for `AshPaperTrail`.
  """

  def allow_resource_versions({m, f, a}, resource) do
    apply(m, f, a) && allow_resource_versions(nil, resource)
  end

  @regex ~r/\.Version$/
  def allow_resource_versions(nil, resource) do
    resource_name = to_string(resource)

    if String.match?(resource_name, @regex) do
      original_resource =
        try do
          resource_name
          |> String.replace(@regex, "")
          |> String.to_existing_atom()
        rescue
          ArgumentError -> false
        end

      original_resource && AshPaperTrail.Resource in Spark.extensions(original_resource)
    else
      false
    end
  end
end
