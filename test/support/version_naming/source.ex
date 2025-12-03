defmodule AshPaperTrail.Test.VersionNaming.Source do
  use Ash.Resource,
    domain: AshPaperTrail.Test.VersionNaming.Domain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshPaperTrail.Resource],
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

  paper_trail do
    # Explicitly configure a different version resource module to avoid
    # colliding with the app-defined Source.Version.
    version_resource(AshPaperTrail.Test.VersionNaming.SourceVersionResource)
  end
end
