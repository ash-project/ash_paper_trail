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
  def allow_resource_versions(nil, resource) when not is_atom(resource), do: false

  def allow_resource_versions(nil, resource) when is_atom(resource) do
    if Code.ensure_loaded?(resource) do
      cond do
        function_exported?(resource, :resource_version?, 0) and safe_resource_version?(resource) ->
          cond do
            function_exported?(resource, :version_of, 0) ->
              case safe_version_of(resource) do
                {:ok, original_resource} ->
                  AshPaperTrail.Resource in Spark.extensions(original_resource)

                :error ->
                  false
              end

            true ->
              relationship_fallback(resource) || regex_fallback(resource)
          end

        true ->
          regex_fallback(resource)
      end
    else
      false
    end
  end

  defp safe_resource_version?(resource) do
    try do
      resource.resource_version?()
    rescue
      _ ->
        false
    end
  end

  defp safe_version_of(resource) do
    try do
      {:ok, resource.version_of()}
    rescue
      _ ->
        :error
    end
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

  defp regex_fallback(resource) do
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
