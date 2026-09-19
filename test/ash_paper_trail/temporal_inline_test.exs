# SPDX-FileCopyrightText: 2022 ash_paper_trail contributors <https://github.com/ash-project/ash_paper_trail/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshPaperTrail.TemporalInlineTest do
  use ExUnit.Case, async: false

  alias AshPaperTrail.Test.Accounts

  alias AshPaperTrail.Test.Posts.{
    TemporalPost,
    TemporalPreviousValuesPost,
    TemporalSnapshotPost,
    TemporalUpsertPost
  }

  import ExUnit.CaptureIO
  require Ash.Query

  @t1 ~U[2026-01-01 00:00:00Z]
  @t2 ~U[2026-02-01 00:00:00Z]
  @t3 ~U[2026-03-01 00:00:00Z]

  setup do
    on_exit(fn ->
      Ash.DataLayer.Ets.stop(TemporalPost)
      Ash.DataLayer.Ets.stop(TemporalSnapshotPost)
      Ash.DataLayer.Ets.stop(TemporalPreviousValuesPost)
      Ash.DataLayer.Ets.stop(TemporalUpsertPost)
      Ash.DataLayer.Ets.stop(Accounts.User)
    end)

    %{
      user: Accounts.User.create!(%{name: "bob"}),
      other_user: Accounts.User.create!(%{name: "alice"})
    }
  end

  defp version_at(resource, id, as_of) do
    Ash.get!(resource, id, as_of: as_of)
  end

  describe "resource definition" do
    test "no version resource is generated" do
      refute Code.ensure_loaded?(TemporalPost.Version)
      refute Ash.Resource.Info.relationship(TemporalPost, :paper_trail_versions)
    end

    test "the version attributes are added to the resource, non-public and non-writable" do
      for name <- [
            :version_action_type,
            :version_action_name,
            :changes,
            :user_id,
            :reason_for_change
          ] do
        assert %{writable?: false, public?: false} =
                 Ash.Resource.Info.attribute(TemporalPost, name),
               "expected #{name} to be a non-public, non-writable attribute"
      end

      assert %{destination: Accounts.User} = Ash.Resource.Info.relationship(TemporalPost, :user)

      assert AshPaperTrail.Resource.Info.temporal_inline_attributes(TemporalPost) ==
               [
                 :version_action_type,
                 :version_action_name,
                 :changes,
                 :user_id,
                 :reason_for_change
               ]
    end

    test "snapshot mode adds no changes attribute, and chosen attributes can be public" do
      refute Ash.Resource.Info.attribute(TemporalSnapshotPost, :changes)

      assert %{public?: true} =
               Ash.Resource.Info.attribute(TemporalSnapshotPost, :version_action_type)

      assert %{public?: false} =
               Ash.Resource.Info.attribute(TemporalSnapshotPost, :version_action_inputs)
    end

    test "public_version_attributes must name version attributes" do
      output =
        capture_io(:stderr, fn ->
          defmodule BadPublic do
            use Ash.Resource,
              domain: AshPaperTrail.Test.Posts.Domain,
              data_layer: Ash.DataLayer.Ets,
              extensions: [AshPaperTrail.Resource],
              validate_domain_inclusion?: false

            temporal do
              strategy :context
            end

            paper_trail do
              mode(:temporal_inline)
              public_version_attributes([:version_action_type, :name])
            end

            attributes do
              uuid_primary_key :id
              attribute :name, :string
            end
          end
        end)

      assert output =~ "Got: `name`"
    end

    test "the version attributes are not accepted as input" do
      refute :version_action_type in Ash.Resource.Info.action(TemporalPost, :create).accept
      refute :changes in Ash.Resource.Info.action(TemporalPost, :update).accept
    end

    # Verifier errors on modules defined at runtime are reported as warnings.
    test "requires a temporal resource" do
      output =
        capture_io(:stderr, fn ->
          defmodule NotTemporal do
            use Ash.Resource,
              domain: AshPaperTrail.Test.Posts.Domain,
              data_layer: Ash.DataLayer.Ets,
              extensions: [AshPaperTrail.Resource],
              validate_domain_inclusion?: false

            paper_trail do
              mode(:temporal_inline)
            end

            attributes do
              uuid_primary_key :id
            end
          end
        end)

      assert output =~ "`mode :temporal_inline` requires a temporal resource"
    end

    test "rejects options that only configure the version resource" do
      output =
        capture_io(:stderr, fn ->
          defmodule BadOptions do
            use Ash.Resource,
              domain: AshPaperTrail.Test.Posts.Domain,
              data_layer: Ash.DataLayer.Ets,
              extensions: [AshPaperTrail.Resource],
              validate_domain_inclusion?: false

            temporal do
              strategy :context
            end

            paper_trail do
              mode(:temporal_inline)
              attributes_as_attributes [:name]
              mixin SomeMixin
            end

            attributes do
              uuid_primary_key :id
              attribute :name, :string
            end
          end
        end)

      assert output =~ "must not be set: `attributes_as_attributes`, `mixin`"
    end
  end

  describe "create" do
    test "stamps the row with the action, actor, metadata and changes", %{user: user} do
      post =
        TemporalPost.create!(%{subject: "subject", body: "body", secret: "hush"},
          actor: user,
          as_of: @t1,
          context: %{paper_trail_metadata: %{reason_for_change: "initial creation"}}
        )

      assert post.version_action_type == :create
      assert post.version_action_name == :create
      assert post.user_id == user.id
      assert post.reason_for_change == "initial creation"
      assert post.changes == %{subject: "subject", body: "body", secret: "hush", views: 0}
      assert %Ash.Range{lower: @t1, upper: nil} = post.valid_at
    end

    test "on the bulk path too", %{user: user} do
      %Ash.BulkResult{records: [post]} =
        Ash.bulk_create!([%{subject: "subject", body: "body"}], TemporalPost, :create,
          actor: user,
          as_of: @t1,
          return_records?: true,
          context: %{paper_trail_metadata: %{reason_for_change: "bulk import"}}
        )

      assert post.version_action_type == :create
      assert post.user_id == user.id
      assert post.reason_for_change == "bulk import"
      assert post.changes.subject == "subject"
    end
  end

  describe "update" do
    setup %{user: user} do
      post =
        TemporalPost.create!(%{subject: "subject", body: "body"},
          actor: user,
          as_of: @t1,
          context: %{paper_trail_metadata: %{reason_for_change: "initial creation"}}
        )

      %{post: post}
    end

    test "the new version is stamped and the previous version keeps its stamp", %{
      post: post,
      other_user: other_user
    } do
      TemporalPost.update!(post, %{body: "new body"},
        actor: other_user,
        as_of: @t2,
        context: %{paper_trail_metadata: %{reason_for_change: "fix typo"}}
      )

      current = version_at(TemporalPost, post.id, @t2)
      assert current.body == "new body"
      assert current.version_action_type == :update
      assert current.version_action_name == :update
      assert current.user_id == other_user.id
      assert current.reason_for_change == "fix typo"
      assert current.changes == %{body: "new body"}
      assert %Ash.Range{lower: @t2, upper: nil} = current.valid_at

      previous = version_at(TemporalPost, post.id, @t1)
      assert previous.body == "body"
      assert previous.version_action_type == :create
      assert previous.user_id == post.user_id
      assert previous.reason_for_change == "initial creation"
      assert %Ash.Range{lower: @t1, upper: @t2} = previous.valid_at
    end

    test "a no-op update produces no new version when only_when_changed? is true", %{post: post} do
      TemporalPost.update!(post, %{body: "body"}, as_of: @t2)

      current = version_at(TemporalPost, post.id, @t2)
      assert %Ash.Range{lower: @t1, upper: nil} = current.valid_at
      assert current.version_action_type == :create
    end

    test "atomic updates are stamped and their changes are built from the atomics", %{
      post: post,
      other_user: other_user
    } do
      TemporalPost.increment_views!(post, actor: other_user, as_of: @t2)

      current = version_at(TemporalPost, post.id, @t2)
      assert current.views == 1
      assert current.version_action_type == :update
      assert current.version_action_name == :increment_views
      assert current.user_id == other_user.id
      assert current.changes == %{views: 1}

      assert %{views: 0, changes: %{body: "body", subject: "subject", views: 0}} =
               version_at(TemporalPost, post.id, @t1)
    end

    test "bulk atomic updates are stamped", %{post: post, other_user: other_user} do
      %Ash.BulkResult{records: [current]} =
        TemporalPost
        |> Ash.Query.filter(id == ^post.id)
        |> Ash.bulk_update!(:update, %{body: "bulk body"},
          actor: other_user,
          as_of: @t2,
          strategy: :atomic,
          return_records?: true
        )

      assert current.body == "bulk body"
      assert current.version_action_type == :update
      assert current.user_id == other_user.id
      assert current.changes == %{body: "bulk body"}
      assert %Ash.Range{lower: @t2, upper: nil} = current.valid_at
    end

    test "when versioning is disabled the new version's stamp is cleared", %{post: post} do
      TemporalPost.silent_update!(post, %{body: "new body"}, as_of: @t2)

      current = version_at(TemporalPost, post.id, @t2)
      assert current.body == "new body"
      assert is_nil(current.version_action_type)
      assert is_nil(current.version_action_name)
      assert is_nil(current.user_id)
      assert is_nil(current.reason_for_change)
      assert is_nil(current.changes)

      assert %{version_action_type: :create} = version_at(TemporalPost, post.id, @t1)
    end

    test "ignored actions clear the stamp the same way", %{post: post} do
      TemporalPost.ignored_update!(post, %{body: "new body"}, as_of: @t2)

      assert %{body: "new body", version_action_type: nil} =
               version_at(TemporalPost, post.id, @t2)
    end

    test "sensitive attributes are redacted in changes when configured", %{post: post} do
      TemporalPost.update!(post, %{secret: "shh"},
        as_of: @t2,
        context: %{sensitive_attributes: :redact}
      )

      assert %{changes: %{secret: "REDACTED"}} = version_at(TemporalPost, post.id, @t2)
    end
  end

  describe "previous_values tracking" do
    test "stores nothing on create and the previous values of changed attributes on update" do
      post = TemporalPreviousValuesPost.create!(%{subject: "subject", body: "body"}, as_of: @t1)
      assert post.changes == %{}

      TemporalPreviousValuesPost.update!(post, %{body: "new body"}, as_of: @t2)
      assert %{changes: %{body: "body"}} = version_at(TemporalPreviousValuesPost, post.id, @t2)
    end

    test "is built from references when the update is atomic" do
      post = TemporalPreviousValuesPost.create!(%{subject: "subject", body: "body"}, as_of: @t1)
      TemporalPreviousValuesPost.increment_views!(post, %{body: "new body"}, as_of: @t2)

      current = version_at(TemporalPreviousValuesPost, post.id, @t2)
      assert current.views == 1
      assert current.body == "new body"
      assert current.changes == %{views: 0, body: "body"}

      %Ash.BulkResult{records: [current]} =
        TemporalPreviousValuesPost
        |> Ash.Query.filter(id == ^post.id)
        |> Ash.bulk_update!(:update, %{subject: "new subject"},
          as_of: @t3,
          strategy: :atomic,
          return_records?: true
        )

      assert current.changes == %{subject: "subject"}
    end
  end

  describe "only_when_changed? false with snapshot tracking" do
    test "a no-op update still produces a stamped version, and inputs are stored" do
      post = TemporalSnapshotPost.create!(%{subject: "subject", body: "body"}, as_of: @t1)
      assert post.version_action_type == :create
      assert post.version_action_inputs == %{subject: "subject", body: "body"}

      TemporalSnapshotPost.update!(post, %{body: "body"}, as_of: @t2)

      current = version_at(TemporalSnapshotPost, post.id, @t2)
      assert %Ash.Range{lower: @t2, upper: nil} = current.valid_at
      assert current.version_action_type == :update
      assert current.version_action_inputs == %{body: "body"}

      assert %Ash.Range{lower: @t1, upper: @t2} =
               version_at(TemporalSnapshotPost, post.id, @t1).valid_at
    end
  end

  describe "destroy" do
    test "ends the record's validity and leaves the history untouched", %{user: user} do
      post = TemporalPost.create!(%{subject: "subject"}, actor: user, as_of: @t1)
      current = TemporalPost.update!(post, %{body: "body"}, actor: user, as_of: @t2)
      TemporalPost.destroy!(current, as_of: @t3)

      assert {:error, %Ash.Error.Invalid{}} = Ash.get(TemporalPost, post.id, as_of: @t3)

      assert %{version_action_type: :update, body: "body"} =
               version_at(TemporalPost, post.id, @t2)

      assert %{version_action_type: :create} = version_at(TemporalPost, post.id, @t1)
    end
  end

  describe "upsert" do
    test "the stamp is refreshed even when it is not among upsert_fields", %{
      user: user,
      other_user: other_user
    } do
      post =
        TemporalUpsertPost.upsert!(%{subject: "subject", body: "body"}, actor: user, as_of: @t1)

      assert post.user_id == user.id

      TemporalUpsertPost.upsert!(%{subject: "subject", body: "new body"},
        actor: other_user,
        as_of: @t2,
        context: %{paper_trail_metadata: %{reason_for_change: "re-imported"}}
      )

      current = version_at(TemporalUpsertPost, post.id, @t2)
      assert current.body == "new body"
      assert current.version_action_type == :create
      assert current.version_action_name == :upsert
      assert current.user_id == other_user.id
      assert current.reason_for_change == "re-imported"
      assert current.changes == %{subject: "subject", body: "new body", views: 0}
      assert %Ash.Range{lower: @t2, upper: nil} = current.valid_at

      assert %{user_id: user_id, valid_at: %Ash.Range{lower: @t1, upper: @t2}} =
               version_at(TemporalUpsertPost, post.id, @t1)

      assert user_id == user.id
    end
  end
end
