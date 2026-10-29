# SPDX-FileCopyrightText: 2022 ash_paper_trail contributors <https://github.com/ash-project/ash_paper_trail/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshPaperTrail.IgnoreAttributesTest do
  use ExUnit.Case, async: false

  defmodule Domain do
    use Ash.Domain, validate_config_inclusion?: false

    resources do
      allow_unregistered? true
    end
  end

  defmodule Post do
    use Ash.Resource,
      domain: Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshPaperTrail.Resource],
      validate_domain_inclusion?: false

    ets do
      private? true
    end

    paper_trail do
      change_tracking_mode :changes_only
      only_when_changed? true
      ignore_attributes [:ignored_field]
    end

    attributes do
      uuid_primary_key :id
      attribute :body, :string, public?: true
      attribute :ignored_field, :string, public?: true
    end

    actions do
      default_accept :*
      defaults [:create, :read]

      update :update do
        require_atomic? false
      end
    end
  end

  test "only changes to tracked attributes create an update version" do
    post =
      Post
      |> Ash.Changeset.for_create(:create, %{body: "original", ignored_field: "original"})
      |> Ash.create!()

    post =
      post
      |> Ash.Changeset.for_update(:update, %{ignored_field: "changed"})
      |> Ash.update!(atomic_upgrade?: false)

    assert post.ignored_field == "changed"
    assert [%{version_action_type: :create}] = Ash.read!(Post.Version)

    post
    |> Ash.Changeset.for_update(:update, %{body: "changed", ignored_field: "changed again"})
    |> Ash.update!(atomic_upgrade?: false)

    versions = Ash.read!(Post.Version)
    assert length(versions) == 2

    assert [%{changes: %{body: "changed"}}] =
             Enum.filter(versions, &(&1.version_action_type == :update))
  end
end
