defmodule AshPaperTrail.VersionResourceNamingTest do
  use ExUnit.Case

  alias AshPaperTrail.Test.VersionNaming.Domain
  alias AshPaperTrail.Test.VersionNaming.Source
  alias AshPaperTrail.Test.VersionNaming.Source.Version, as: SourceVersion
  alias AshPaperTrail.Test.VersionNaming.SourceVersionResource

  describe "generated version resource naming" do
    test "uses explicit version_resource module and does not conflict with an app-defined Source.Version" do
      assert Code.ensure_loaded?(SourceVersionResource)
      assert SourceVersionResource.resource_version?()

      assert Code.ensure_loaded?(SourceVersion)
      refute function_exported?(SourceVersion, :resource_version?, 0)

      assert Code.ensure_loaded?(Source)
    end

    test "version_resource/1 returns the explicit version_resource module for Source" do
      assert AshPaperTrail.Resource.Info.version_resource(Source) == SourceVersionResource
    end

    test "version_resource/1 falls back to X.Version for version modules themselves" do
      assert AshPaperTrail.Resource.Info.version_resource(SourceVersion) ==
               Module.concat([SourceVersion, Version])
    end

    test "writes versions for Source into the explicitly configured version resource module" do
      Ash.create!(Source, %{name: "named source"}, domain: Domain)

      versions_in_explicit_module =
        Ash.read!(SourceVersionResource, domain: Domain)

      versions_in_app_defined_version =
        Ash.read!(SourceVersion, domain: Domain)

      assert length(versions_in_explicit_module) == 1

      assert Enum.at(versions_in_explicit_module, 0).changes[:name] == "named source"

      assert versions_in_app_defined_version == []
    end
  end
end
