# SPDX-FileCopyrightText: 2022 ash_paper_trail contributors <https://github.com/ash-project/ash_paper_trail/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshPaperTrail.Resource.Verifiers.ValidateTemporalInline do
  @moduledoc "Validates the configuration of a resource using `mode :temporal_inline`"
  use Spark.Dsl.Verifier
  alias Spark.Dsl.Verifier

  @version_resource_options [
    primary_key_type: :uuid,
    attributes_as_attributes: [],
    mixin: nil,
    reference_source?: true,
    versions_relationship_name: :paper_trail_versions,
    relationship_opts: nil,
    version_resource: nil,
    version_extensions: [],
    table_name: nil,
    public_timestamps?: false,
    store_resource_identifier?: false,
    resource_identifier: nil
  ]

  @impl true
  def verify(dsl_state) do
    if AshPaperTrail.Resource.Info.temporal_inline?(dsl_state) do
      module = Verifier.get_persisted(dsl_state, :module)

      cond do
        not Ash.Resource.Info.temporal?(dsl_state) ->
          {:error,
           Spark.Error.DslError.exception(
             module: module,
             path: [:paper_trail, :mode],
             message: """
             `mode :temporal_inline` requires a temporal resource.

             Add a `temporal` section to #{inspect(module)}, and use a data layer that supports
             temporal resources, or use `mode :version_resource`.
             """
           )}

        (unknown = unknown_public_attributes(dsl_state)) != [] ->
          {:error,
           Spark.Error.DslError.exception(
             module: module,
             path: [:paper_trail, :public_version_attributes],
             message: """
             `public_version_attributes` may only name version attributes added by `mode :temporal_inline`.

             Got: #{Enum.map_join(unknown, ", ", &"`#{&1}`")}
             Valid: #{Enum.map_join(AshPaperTrail.Resource.Info.temporal_inline_attributes(dsl_state), ", ", &"`#{&1}`")}
             """
           )}

        (offending = offending_options(dsl_state)) != [] ->
          {:error,
           Spark.Error.DslError.exception(
             module: module,
             path: [:paper_trail, :mode],
             message: """
             `mode :temporal_inline` does not generate a version resource, so the following
             options have no effect and must not be set: #{Enum.map_join(offending, ", ", &"`#{&1}`")}
             """
           )}

        true ->
          :ok
      end
    else
      :ok
    end
  end

  defp unknown_public_attributes(dsl_state) do
    AshPaperTrail.Resource.Info.public_version_attributes(dsl_state) --
      AshPaperTrail.Resource.Info.temporal_inline_attributes(dsl_state)
  end

  defp offending_options(dsl_state) do
    @version_resource_options
    |> Enum.filter(fn {key, default} ->
      Verifier.get_option(dsl_state, [:paper_trail], key) != default
    end)
    |> Enum.map(&elem(&1, 0))
  end
end
