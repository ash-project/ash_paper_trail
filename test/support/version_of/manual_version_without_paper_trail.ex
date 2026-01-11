defmodule AshPaperTrail.Test.VersionOf.NonPaperTrailResource do
  @moduledoc false

  use Ash.Resource,
    domain: nil,
    data_layer: Ash.DataLayer.Ets,
    validate_domain_inclusion?: false

  ets do
    private? true
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
    end
  end

  actions do
    default_accept :*
    defaults [:create, :read, :update, :destroy]
  end
end

defmodule AshPaperTrail.Test.VersionOf.ManualVersionWithoutPaperTrail do
  @moduledoc false

  alias AshPaperTrail.Test.VersionOf.NonPaperTrailResource

  # Mimics a version resource (has resource_version?/0 and version_of/0)
  # but its underlying resource does NOT use AshPaperTrail.Resource.
  def resource_version?, do: true
  def version_of, do: NonPaperTrailResource
end
