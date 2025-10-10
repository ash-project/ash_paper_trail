# SPDX-FileCopyrightText: 2020 Zach Daniel
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

  defmodule Domain do
    use Ash.Domain, extensions: [AshPaperTrail.Domain], validate_config_inclusion?: false

    resources do
      resource Tag
      resource Tag.Version
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
end
