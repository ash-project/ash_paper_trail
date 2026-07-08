# SPDX-FileCopyrightText: 2022 ash_paper_trail contributors <https://github.com/ash-project/ash_paper_trail/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshPaperTrail.Resource.PrimaryKey do
  @moduledoc false
  # Shared version-source primary key mapping for single and composite keys.

  import Ash.Expr

  @version_source_id :version_source_id

  @doc "Returns `{source_pk, version_attr}` pairs for a resource or DSL state."
  def pairs(resource) do
    resource
    |> Ash.Resource.Info.primary_key()
    |> Enum.map(&{&1, version_source_attribute_name(resource, &1)})
  end

  # Returns true when the resource has more than one primary key attribute.
  def composite?(resource) do
    resource |> Ash.Resource.Info.primary_key() |> length() > 1
  end

  # Returns the version-side attribute name for a given source PK — :version_source_id for
  # single PK, :version_source_<name> for composite.
  # sobelow_skip ["DOS.StringToAtom"]
  def version_source_attribute_name(resource, source_key) do
    case Ash.Resource.Info.primary_key(resource) do
      [_single] -> @version_source_id
      _ -> String.to_atom("version_source_#{source_key}")
    end
  end

  # Returns all version-side attribute names for a resource's primary key(s).
  def version_source_attribute_names(resource) do
    resource
    |> Ash.Resource.Info.primary_key()
    |> Enum.map(&version_source_attribute_name(resource, &1))
  end

  # Returns {source_pk, version_attr, source_attribute} tuples, including type and
  # constraints from the source attribute.
  def mappings(resource) do
    resource
    |> pairs()
    |> Enum.map(fn {source_key, version_attr} ->
      {source_key, version_attr, Ash.Resource.Info.attribute(resource, source_key)}
    end)
  end

  # Builds a map of version attribute names → values from a source record,
  # for use when creating a version at runtime.
  def version_source_input(result, resource) do
    Map.new(pairs(resource), fn {source_key, version_attr} ->
      {version_attr, Map.get(result, source_key)}
    end)
  end

  # Filter for `has_many :paper_trail_versions` on the source resource.
  def source_versions_filter(resource) do
    resource
    |> pairs()
    |> Enum.map(fn {source_key, version_attr} ->
      expr(^ref(version_attr) == parent(^ref(source_key)))
    end)
    |> Enum.reduce(fn right, left -> expr(^left and ^right) end)
  end

  # Filter for `has_one :version_source` on the version resource.
  def version_source_filter(resource) do
    resource
    |> pairs()
    |> Enum.map(fn {source_key, version_attr} ->
      expr(^ref(source_key) == parent(^ref(version_attr)))
    end)
    |> Enum.reduce(fn right, left -> expr(^left and ^right) end)
  end
end
