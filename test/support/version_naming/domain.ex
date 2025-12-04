defmodule AshPaperTrail.Test.VersionNaming.Domain do
  @moduledoc false

  use Ash.Domain,
    extensions: [AshPaperTrail.Domain],
    validate_config_inclusion?: false

  resources do
    resource AshPaperTrail.Test.VersionNaming.Source
    resource AshPaperTrail.Test.VersionNaming.Source.Version
  end
end
