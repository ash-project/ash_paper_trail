# SPDX-FileCopyrightText: 2022 ash_paper_trail contributors <https://github.com/ash-project/ash_paper_trail/graphs/contributors>
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
      function_exported?(resource, :version_source_resource, 0) ->
        source = resource.version_source_resource()
        AshPaperTrail.Resource in Spark.extensions(source)

      legacy_version_module?(resource) ->
        original_resource =
          resource
          |> to_string()
          |> String.replace(@regex, "")
          |> String.to_existing_atom()

        AshPaperTrail.Resource in Spark.extensions(original_resource)

      true ->
        false
    end
  rescue
    ArgumentError -> false
  end

  defp legacy_version_module?(resource) do
    String.match?(to_string(resource), @regex)
  end
end
