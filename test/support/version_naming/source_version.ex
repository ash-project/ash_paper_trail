defmodule AshPaperTrail.Test.VersionNaming.Source.Version do
  use Ash.Resource,
    domain: AshPaperTrail.Test.VersionNaming.Domain,
    data_layer: Ash.DataLayer.Ets,
    validate_domain_inclusion?: false

  ets do
    private? true
  end

  attributes do
    uuid_primary_key :id

    attribute :label, :string do
      allow_nil? false
      public? true
    end
  end

  actions do
    default_accept :*
    defaults [:create, :read, :update, :destroy]
  end
end
