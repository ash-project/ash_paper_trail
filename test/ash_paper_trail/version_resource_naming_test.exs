defmodule AshPaperTrail.VersionResourceNamingTest do
  use ExUnit.Case

  setup_all do
    # Ensure the support resource modules used by these tests are compiled and loaded
    # deterministically before any tests run. This avoids intermittent failures where
    # compile/load ordering leaves the Source module undefined at assertion time.
    for mod <- [
          AshPaperTrail.Test.VersionNaming.Source,
          AshPaperTrail.Test.VersionNaming.Source.Version,
          AshPaperTrail.Test.VersionNaming.SourceVersionResource
        ] do
      case Code.ensure_compiled(mod) do
        {:module, _} -> :ok
        {:error, reason} -> raise "Failed to ensure compiled #{inspect(mod)}: #{inspect(reason)}"
      end
    end

    :ok
  end

  alias AshPaperTrail.Test.VersionNaming.Domain
  alias AshPaperTrail.Test.VersionNaming.Source
  alias AshPaperTrail.Test.VersionNaming.Source.Version, as: SourceVersion
  alias AshPaperTrail.Test.VersionNaming.SourceVersionResource
  alias AshPaperTrail.Test.VersionOf.ManualVersionWithoutPaperTrail

  describe "generated version resource naming" do
    test "uses explicit version_resource module and does not conflict with an app-defined Source.Version" do
      # Explicit version resource behaves like a version resource
      assert SourceVersionResource.resource_version?()

      # App-defined Source.Version is a regular resource, not a version resource
      refute function_exported?(SourceVersion, :resource_version?, 0)

      # Source itself must still be a valid resource
      assert function_exported?(Source, :__info__, 1)
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

    test "generated version resource defines version_of/0 returning the original resource" do
      # Calling version_of/0 forces the module to be loaded and ensures the function exists
      assert SourceVersionResource.version_of() == Source
    end

    test "allow_resource_versions/2 accepts generated version resources via version_of/0" do
      assert AshPaperTrail.allow_resource_versions(nil, SourceVersionResource)
    end
  end

  describe "allow_resource_versions/2 with manual version_of/0" do
    test "rejects version modules whose version_of/0 points to a non-paper-trail resource" do
      # These calls both verify the functions exist and force module loading
      assert ManualVersionWithoutPaperTrail.resource_version?()

      assert ManualVersionWithoutPaperTrail.version_of() ==
               AshPaperTrail.Test.VersionOf.NonPaperTrailResource

      refute AshPaperTrail.allow_resource_versions(nil, ManualVersionWithoutPaperTrail)
    end
  end
end
