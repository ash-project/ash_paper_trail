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

  def allow_resource_versions(nil, resource) when not is_atom(resource), do: false

  def allow_resource_versions(nil, resource) when is_atom(resource) do
    if safe_resource_version?(resource) do
      if function_exported?(resource, :version_of, 0) do
        case safe_version_of(resource) do
          {:ok, original_resource} ->
            AshPaperTrail.Resource in Spark.extensions(original_resource)

          :error ->
            false
        end
      else
        relationship_fallback(resource)
      end
    else
      false
    end
  end

  defp safe_resource_version?(resource) do
    resource.resource_version?()
  rescue
    _ ->
      false
  end

  defp safe_version_of(resource) do
    {:ok, resource.version_of()}
  rescue
    _ ->
      :error
  end

  defp relationship_fallback(resource) do
    relationships = Ash.Resource.Info.relationships(resource)

    case Enum.find(relationships, &(&1.name == :version_source and &1.type == :belongs_to)) do
      nil ->
        false

      relationship ->
        AshPaperTrail.Resource in Spark.extensions(relationship.destination)
    end
  end
end
