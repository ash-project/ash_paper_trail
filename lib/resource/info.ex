defmodule AshPaperTrail.Resource.Info do
  @moduledoc "Introspection helpers for `AshPaperTrail.Resource`"

  @spec reference_source?(Spark.Dsl.t() | Ash.Resource.t()) :: boolean
  def reference_source?(resource) do
    Spark.Dsl.Extension.get_opt(resource, [:paper_trail], :reference_source?, true)
  end

  @spec on_actions(Spark.Dsl.t() | Ash.Resource.t()) :: [atom]
  def on_actions(resource) do
    Spark.Dsl.Extension.get_opt(resource, [:paper_trail], :on_actions, nil) ||
      resource
      |> Ash.Resource.Info.actions()
      |> Enum.reject(&(&1.type == :read))
      |> Enum.map(& &1.name)
  end

  @spec attributes_as_attributes(Spark.Dsl.t() | Ash.Resource.t()) :: [atom]
  def attributes_as_attributes(resource) do
    Spark.Dsl.Extension.get_opt(resource, [:paper_trail], :attributes_as_attributes, [])
  end

  @spec change_tracking_mode(Spark.Dsl.t() | Ash.Resource.t()) :: atom
  def change_tracking_mode(resource) do
    Spark.Dsl.Extension.get_opt(resource, [:paper_trail], :change_tracking_mode, [])
  end

  @spec ignore_attributes(Spark.Dsl.t() | Ash.Resource.t()) :: [atom]
  def ignore_attributes(resource) do
    Spark.Dsl.Extension.get_opt(resource, [:paper_trail], :ignore_attributes, []) ++
      [:created_at, :updated_at] ++ Ash.Resource.Info.primary_key(resource)
  end

  @spec mixin(Spark.Dsl.t() | Ash.Resource.t()) :: mfa | nil
  def mixin(resource) do
    Spark.Dsl.Extension.get_opt(resource, [:paper_trail], :mixin, nil)
  end

  @spec version_extensions(Spark.Dsl.t() | Ash.Resource.t()) :: Keyword.t()
  def version_extensions(resource) do
    Spark.Dsl.Extension.get_opt(resource, [:paper_trail], :version_extensions, [])
  end

  @spec version_resource(Spark.Dsl.t() | Ash.Resource.t()) :: Ash.Resource.t()
  def version_resource(resource) do
    if is_atom(resource) do
      Module.concat([resource, Version])
    else
      Module.concat([Spark.Dsl.Extension.get_persisted(resource, :module), Version])
    end
  end
end
