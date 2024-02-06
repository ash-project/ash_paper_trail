defmodule AshPaperTrail.Resource.Transformers.CreateVersionResourceTest do
  use ExUnit.Case

  defmodule Tag do
    use Ash.Resource,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshPaperTrail.Resource],
      validate_api_inclusion?: false

    ets do
      private? true
    end

    attributes do
      attribute :name, :string do
        allow_nil? false
        primary_key? true
        constraints max_length: 20
      end
    end
  end

  defmodule Api do
    use Ash.Api, extensions: [AshPaperTrail.Api], validate_config_inclusion?: false

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
      assert version_source_id.constraints == [allow_empty?: false, trim?: true, max_length: 20]
    end
  end
end
