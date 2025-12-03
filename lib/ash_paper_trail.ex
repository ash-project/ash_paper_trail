# SPDX-FileCopyrightText: 2022 ash_paper_trail contributors <https://github.com/ash-project/ash_paper_trail/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshPaperTrail do
  @moduledoc """
  Documentation for `AshPaperTrail`.
  """

  def allow_resource_versions({m, f, a}, resource) do
    apply(m, f, a) || allow_resource_versions(nil, resource)
  end

  @regex ~r/\.Version$/
  def allow_resource_versions(nil, resource) do
    cond do
      is_atom(resource) and function_exported?(resource, :resource_version?, 0) and
          resource.resource_version?() ->
        relationships = Ash.Resource.Info.relationships(resource)

        case Enum.find(relationships, &(&1.name == :version_source and &1.type == :belongs_to)) do
          nil ->
            false

          relationship ->
            AshPaperTrail.Resource in Spark.extensions(relationship.destination)
        end

      true ->
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
end
