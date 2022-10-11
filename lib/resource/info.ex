defmodule AshPaperTrail.Resource.Info do
  @moduledoc "Introspection helpers for `AshPaperTrail.Resource`"

  @spec reference_source?(Spark.Dsl.t() | Ash.Resource.t()) :: boolean
  def reference_source?(resource) do
    Spark.Dsl.Extension.get_opt(resource, [:versions], :reference_source?, true)
  end

  @spec on_actions(Spark.Dsl.t() | Ash.Resource.t()) :: [atom]
  def on_actions(resource) do
    Spark.Dsl.Extension.get_opt(resource, [:versions], :on_actions, nil) ||
      resource
      |> Ash.Resource.Info.actions()
      |> Enum.reject(&(&1.type == :read))
      |> Enum.map(& &1.name)
  end

  @spec on_actions(Spark.Dsl.t() | Ash.Resource.t()) :: [atom]
  def ignore_attributes(resource) do
    Spark.Dsl.Extension.get_opt(resource, [:versions], :ignore_attributes, []) ++
      [:created_at, :updated_at] ++ Ash.Resource.Info.primary_key(resource)
  end

  @spec on_actions(Spark.Dsl.t() | Ash.Resource.t()) :: mfa | nil
  def mixin(resource) do
    Spark.Dsl.Extension.get_opt(resource, [:versions], :mixin, nil)
  end

  @spec on_actions(Spark.Dsl.t() | Ash.Resource.t()) :: Ash.Resource.t()
  def version_resource(resource) do
    if is_atom(resource) do
      Module.concat([resource, Version])
    else
      Module.concat([Spark.Dsl.Extension.get_persisted(resource, :module), Version])
    end
  end
end
