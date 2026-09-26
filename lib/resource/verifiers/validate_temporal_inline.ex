# SPDX-FileCopyrightText: 2022 ash_paper_trail contributors <https://github.com/ash-project/ash_paper_trail/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshPaperTrail.Resource.Verifiers.ValidateTemporalInline do
  @moduledoc "Validates the configuration of a resource using `mode :temporal_inline`"
  use Spark.Dsl.Verifier
  alias Spark.Dsl.Verifier

  # Options that only configure a generated version resource, with their defaults. The
  # inline version resource mirrors the resource's own table, so these never apply to it.
  @inline_version_resource_options [
    primary_key_type: :uuid,
    attributes_as_attributes: [],
    reference_source?: true,
    table_name: nil,
    public_timestamps?: false,
    store_resource_identifier?: false,
    resource_identifier: nil
  ]

  # These do apply to the inline version resource, when there is one.
  @version_resource_options @inline_version_resource_options ++
                              [
                                mixin: nil,
                                versions_relationship_name: :paper_trail_versions,
                                relationship_opts: nil,
                                version_resource: nil,
                                version_extensions: []
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
             The following options have no effect in `mode :temporal_inline` and must not be set: #{Enum.map_join(offending, ", ", &"`#{&1}`")}

             #{if AshPaperTrail.Resource.Info.version_resource?(dsl_state), do: "The version resource reads the resource's own table, so its keys, attributes and table are fixed.", else: "No version resource is defined unless `version_resource? true` is set."}
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
    options =
      if AshPaperTrail.Resource.Info.version_resource?(dsl_state),
        do: @inline_version_resource_options,
        else: @version_resource_options

    options
    |> Enum.filter(fn {key, default} ->
      Verifier.get_option(dsl_state, [:paper_trail], key) != default
    end)
    |> Enum.map(&elem(&1, 0))
  end
end
