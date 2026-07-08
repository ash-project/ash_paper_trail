# SPDX-FileCopyrightText: 2022 ash_paper_trail contributors <https://github.com/ash-project/ash_paper_trail/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshPaperTrail.Resource.Transformers.CreateVersionResourceTest do
  use ExUnit.Case

  defmodule Tag do
    use Ash.Resource,
      domain: AshPaperTrail.Resource.Transformers.CreateVersionResourceTest.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshPaperTrail.Resource],
      validate_domain_inclusion?: false

    ets do
      private? true
    end

    actions do
      default_accept :*
      defaults [:create, :update, :destroy, :read]
    end

    attributes do
      attribute :name, :string do
        public? true
        allow_nil? false
        primary_key? true
        constraints max_length: 20
      end
    end
  end

  defmodule TagWithCustomVersion do
    use Ash.Resource,
      domain: AshPaperTrail.Resource.Transformers.CreateVersionResourceTest.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshPaperTrail.Resource],
      validate_domain_inclusion?: false

    ets do
      private? true
    end

    paper_trail do
      version_resource(
        AshPaperTrail.Resource.Transformers.CreateVersionResourceTest.TagPaperTrailVersion
      )
    end

    actions do
      default_accept :*
      defaults [:create, :update, :destroy, :read]
    end

    attributes do
      attribute :name, :string do
        public? true
        allow_nil? false
        primary_key? true
      end
    end
  end

  defmodule Domain do
    use Ash.Domain, extensions: [AshPaperTrail.Domain], validate_config_inclusion?: false

    resources do
      resource Tag
      resource Tag.Version
      resource TagWithCustomVersion
      resource AshPaperTrail.Resource.Transformers.CreateVersionResourceTest.TagPaperTrailVersion
    end
  end

  describe "version_resource option" do
    test "uses configured module name" do
      version_module =
        AshPaperTrail.Resource.Transformers.CreateVersionResourceTest.TagPaperTrailVersion

      assert AshPaperTrail.Resource.Info.version_resource(TagWithCustomVersion) ==
               version_module

      assert function_exported?(version_module, :version_source_resource, 0)

      assert version_module.version_source_resource() == TagWithCustomVersion
    end

    test "allow_resource_versions permits custom version module" do
      version_module =
        AshPaperTrail.Resource.Transformers.CreateVersionResourceTest.TagPaperTrailVersion

      assert AshPaperTrail.allow_resource_versions(nil, version_module)
    end
  end

  describe "attribute :version_source_id" do
    setup do
      version_source_id = Ash.Resource.Info.attribute(Tag.Version, :version_source_id)
      [version_source_id: version_source_id]
    end

    test "uses resource primary key type", %{version_source_id: version_source_id} do
      assert version_source_id.type == Ash.Type.String
    end

    test "uses resource primary key constraints", %{version_source_id: version_source_id} do
      assert Keyword.equal?(version_source_id.constraints,
               allow_empty?: false,
               trim?: true,
               max_length: 20
             )
    end
  end

  defp assert_composite_pk_support(source, version, source_keys) do
    version_keys = AshPaperTrail.Resource.PrimaryKey.version_source_attribute_names(source)

    assert length(version_keys) == length(source_keys)
    refute :version_source_id in version_keys

    for {source_key, version_key} <- Enum.zip(source_keys, version_keys) do
      assert version_key ==
               AshPaperTrail.Resource.PrimaryKey.version_source_attribute_name(source, source_key)

      assert Ash.Resource.Info.attribute(version, version_key)
    end

    assert %{type: :has_one, no_attributes?: true} =
             Ash.Resource.Info.relationship(version, :version_source)

    assert %{type: :has_many, no_attributes?: true} =
             Ash.Resource.Info.relationship(source, :paper_trail_versions)

    result = Map.new(source_keys, &{&1, Ash.UUID.generate()})

    assert AshPaperTrail.Resource.PrimaryKey.version_source_input(result, source) ==
             Map.new(Enum.zip(source_keys, version_keys), fn {source_key, version_key} ->
               {version_key, result[source_key]}
             end)
  end

  describe "composite primary keys" do
    test "supports ten primary key components" do
      source = AshPaperTrail.Test.Posts.TeamMember
      version = AshPaperTrail.Test.Posts.TeamMember.Version

      assert_composite_pk_support(
        source,
        version,
        AshPaperTrail.Test.Posts.TeamMember.composite_keys()
      )
    end
  end
end
