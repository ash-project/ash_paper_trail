# SPDX-FileCopyrightText: 2020 Zach Daniel
#
# SPDX-License-Identifier: MIT

defmodule AshPaperTrail.Domain.Transformers.AllowResourceVersions do
  @moduledoc """
  Adds any version resources to the domain for any resources.
  """

  use Spark.Dsl.Transformer
  alias Spark.Dsl.Transformer

  def transform(dsl_state) do
    if AshPaperTrail.Domain.Info.include_versions?(dsl_state) do
      resources = Ash.Domain.Info.resources(dsl_state)

      Enum.reduce(resources, {:ok, dsl_state}, fn resource, {:ok, dsl_state} ->
        if AshPaperTrail.Resource in Spark.extensions(resource) do
          version_resource = AshPaperTrail.Resource.Info.version_resource(resource)

          if version_resource in resources do
            {:ok, dsl_state}
          else
            entity =
              Transformer.build_entity!(Ash.Domain.Dsl, [:resources], :resource,
                resource: version_resource
              )

            {:ok, Transformer.add_entity(dsl_state, [:resources], entity)}
          end
        else
          {:ok, dsl_state}
        end
      end)
    else
      existing_allow_mfa = Ash.Domain.Info.allow(dsl_state)

      {:ok,
       Transformer.set_option(
         dsl_state,
         [:resources],
         :allow,
         {AshPaperTrail, :allow_resource_versions, [existing_allow_mfa]}
       )}
    end
  end
end
