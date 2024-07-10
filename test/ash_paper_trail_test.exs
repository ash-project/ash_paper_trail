defmodule AshPaperTrailTest do
  @moduledoc false
  use ExUnit.Case
  require Ash.Query

  alias AshPaperTrail.Test.{Accounts, Articles, Posts}

  @valid_attrs %{
    subject: "subject",
    body: "body",
    author: %{first_name: "John", last_name: "Doe"},
    tags: [%{tag: "ash"}, %{tag: "phoenix"}]
  }
  describe "operations over resource api" do
    test "creates work as normal" do
      assert %{subject: "subject", body: "body", tenant: "acme"} =
               Posts.Post.create!(@valid_attrs, tenant: "acme")

      assert [%{subject: "subject", body: "body", tenant: "acme"}] =
               Posts.Post.read!(tenant: "acme")
    end

    test "updates work as normal" do
      assert %{subject: "subject", body: "body", tenant: "acme"} =
               post = Posts.Post.create!(@valid_attrs, tenant: "acme")

      assert %{subject: "new subject", body: "new body"} =
               Posts.Post.update!(post, %{subject: "new subject", body: "new body"})

      assert [%{subject: "new subject", body: "new body"}] =
               Posts.Post.read!(tenant: "acme")
    end

    test "destroys work as normal" do
      assert %{subject: "subject", body: "body", tenant: "acme"} =
               post = Posts.Post.create!(@valid_attrs, tenant: "acme")

      assert :ok = Posts.Post.destroy!(post)

      assert [] = Posts.Post.read!(tenant: "acme")
    end
  end

  describe "version resource" do
    test "a new version is created on create" do
      assert %{subject: "subject", body: "body", id: post_id} =
               Posts.Post.create!(@valid_attrs, tenant: "acme")

      assert [
               %{
                 subject: "subject",
                 body: "body",
                 changes: %{
                   subject: "subject",
                   body: "body",
                   author: %{first_name: "John", last_name: "Doe"},
                   tags: [
                     %{tag: "ash", id: _tag_id1},
                     %{tag: "phoenix", id: _tag_id2}
                   ]
                 },
                 version_action_type: :create,
                 version_action_name: :create,
                 version_source_id: ^post_id
               }
             ] =
               Ash.read!(Posts.Post.Version, tenant: "acme")
    end

    test "a new version is created on a bulk create" do
      %Ash.BulkResult{
        status: :success
      } =
        Ash.bulk_create!([@valid_attrs], Posts.Post, :create, tenant: "acme")

      assert [
               %{
                 subject: "subject",
                 body: "body",
                 changes: %{
                   subject: "subject",
                   body: "body",
                   author: %{first_name: "John", last_name: "Doe"},
                   tags: [
                     %{tag: "ash", id: _tag_id1},
                     %{tag: "phoenix", id: _tag_id2}
                   ]
                 },
                 version_action_type: :create,
                 version_action_name: :create,
                 version_source_id: _post_id
               }
             ] =
               Ash.read!(Posts.Post.Version, tenant: "acme")
    end

    test "a new version is created on update" do
      assert %{subject: "subject", body: "body", id: post_id} =
               post = Posts.Post.create!(@valid_attrs, tenant: "acme")

      assert %{subject: "new subject", body: "new body"} =
               Posts.Post.update!(post, %{subject: "new subject", body: "new body"},
                 tenant: "acme"
               )

      assert [
               %{
                 subject: "subject",
                 body: "body",
                 version_action_type: :create,
                 version_source_id: ^post_id
               },
               %{
                 subject: "new subject",
                 body: "new body",
                 version_action_type: :update,
                 version_source_id: ^post_id
               }
             ] =
               Ash.read!(Posts.Post.Version, tenant: "acme")
               |> Enum.sort_by(& &1.version_inserted_at)
    end

    test "a new version is created on a bulk update with enumerable" do
      %{subject: "subject", body: "body", id: post_id} =
        post = Posts.Post.create!(@valid_attrs, tenant: "acme")

      %Ash.BulkResult{
        status: :success
      } =
        Ash.bulk_update!([post], :update, %{subject: "new subject", body: "new body"},
          tenant: "acme",
          strategy: :stream,
          return_records?: true,
          return_errors?: true
        )

      assert [
               %{
                 subject: "subject",
                 body: "body",
                 changes: %{
                   subject: "subject",
                   body: "body",
                   author: %{first_name: "John", last_name: "Doe"},
                   tags: [
                     %{tag: "ash", id: _tag_id1},
                     %{tag: "phoenix", id: _tag_id2}
                   ]
                 },
                 version_action_type: :create,
                 version_action_name: :create,
                 version_source_id: ^post_id
               },
               %{
                 subject: "new subject",
                 body: "new body",
                 changes: %{
                   subject: "new subject",
                   body: "new body"
                 },
                 version_action_type: :update,
                 version_action_name: :update,
                 version_source_id: ^post_id
               }
             ] =
               Ash.read!(Posts.Post.Version, tenant: "acme")
               |> Enum.sort_by(& &1.version_action_type)
    end

    test "a new version is created on a bulk update with query" do
      %{subject: "subject", body: "body", id: post_id} =
        Posts.Post.create!(@valid_attrs, tenant: "acme")

      %Ash.BulkResult{
        status: :success
      } =
        Posts.Post
        |> Ash.Query.filter(id: post_id)
        |> Ash.bulk_update!(:update, %{subject: "new subject", body: "new body"},
          tenant: "acme",
          strategy: :stream,
          return_records?: true,
          return_errors?: true
        )

      assert [
               %{
                 subject: "subject",
                 body: "body",
                 changes: %{
                   subject: "subject",
                   body: "body",
                   author: %{first_name: "John", last_name: "Doe"},
                   tags: [
                     %{tag: "ash", id: _tag_id1},
                     %{tag: "phoenix", id: _tag_id2}
                   ]
                 },
                 version_action_type: :create,
                 version_action_name: :create,
                 version_source_id: ^post_id
               },
               %{
                 subject: "new subject",
                 body: "new body",
                 changes: %{
                   subject: "new subject",
                   body: "new body"
                 },
                 version_action_type: :update,
                 version_action_name: :update,
                 version_source_id: ^post_id
               }
             ] =
               Ash.read!(Posts.Post.Version, tenant: "acme")
               |> Enum.sort_by(& &1.version_action_type)
    end

    test "the action name is stored" do
      assert AshPaperTrail.Resource.Info.store_action_name?(Posts.Post) == true

      post = Posts.Post.create!(@valid_attrs, tenant: "acme")
      Posts.Post.publish!(post, %{}, tenant: "acme")

      [publish_version] =
        Ash.read!(Posts.Post.Version, tenant: "acme")
        |> Enum.filter(&(&1.version_action_type == :update))

      assert %{version_action_type: :update, version_action_name: :publish} = publish_version
    end

    test "a new version is created on destroy" do
      assert %{subject: "subject", body: "body", id: post_id} =
               post = Posts.Post.create!(@valid_attrs, tenant: "acme")

      assert :ok = Posts.Post.destroy!(post, tenant: "acme")

      assert [
               %{
                 subject: "subject",
                 body: "body",
                 version_action_type: :create,
                 version_source_id: ^post_id
               },
               %{
                 subject: "subject",
                 body: "body",
                 version_action_type: :destroy,
                 version_source_id: ^post_id
               }
             ] =
               Ash.read!(Posts.Post.Version, tenant: "acme")
               |> Enum.sort_by(& &1.version_inserted_at)
    end

    test "a new version is created on destroy with enumerable" do
      %{subject: "subject", body: "body", id: post_id} =
        post = Posts.Post.create!(@valid_attrs, tenant: "acme")

      %Ash.BulkResult{
        status: :success
      } =
        Ash.bulk_destroy!([post], :destroy, %{},
          strategy: :stream,
          tenant: "acme",
          return_errors?: true
        )

      assert [
               %{
                 subject: "subject",
                 body: "body",
                 version_action_type: :create,
                 version_source_id: ^post_id
               },
               %{
                 subject: "subject",
                 body: "body",
                 version_action_type: :destroy,
                 version_source_id: ^post_id
               }
             ] =
               Ash.read!(Posts.Post.Version, tenant: "acme")
               |> Enum.sort_by(& &1.version_inserted_at)
    end

    test "a new version is created on destroy with query" do
      %{subject: "subject", body: "body", id: post_id} =
        Posts.Post.create!(@valid_attrs, tenant: "acme")

      %Ash.BulkResult{
        status: :success
      } =
        Posts.Post
        |> Ash.Query.filter(id: post_id)
        |> Ash.bulk_destroy!(:destroy, %{},
          strategy: :stream,
          tenant: "acme",
          return_errors?: true
        )

      assert [
               %{
                 subject: "subject",
                 body: "body",
                 version_action_type: :create,
                 version_source_id: ^post_id
               },
               %{
                 subject: "subject",
                 body: "body",
                 version_action_type: :destroy,
                 version_source_id: ^post_id
               }
             ] =
               Ash.read!(Posts.Post.Version, tenant: "acme")
               |> Enum.sort_by(& &1.version_inserted_at)
    end
  end

  describe "relationship_opts" do
    test "when no relationship_opts are given the defaults are used" do
      refute Ash.Resource.Info.relationship(Articles.Article, :paper_trail_versions).public?
    end

    test "when public?: true is given it is passed to the relationship" do
      assert Ash.Resource.Info.relationship(Posts.Post, :paper_trail_versions).public?
    end
  end

  describe "changes in :changes_only mode" do
    test "the changes only includes attributes that changed" do
      assert AshPaperTrail.Resource.Info.change_tracking_mode(Posts.Post) == :changes_only

      post = Posts.Post.create!(@valid_attrs, tenant: "acme")
      Posts.Post.update!(post, %{subject: "new subject"}, tenant: "acme")

      [updated_version] =
        Ash.read!(Posts.Post.Version, tenant: "acme")
        |> Enum.filter(&(&1.version_action_type == :update))

      assert [:subject] = Map.keys(updated_version.changes)
    end
  end

  describe "changes in :snapshot mode" do
    test "the changes includes all attributes in :snapshot mode" do
      assert AshPaperTrail.Resource.Info.change_tracking_mode(Articles.Article) == :snapshot

      article = Articles.Article.create!("subject", "body")
      Articles.Article.update!(article, %{subject: "new subject"})

      [updated_version] =
        Ash.read!(Articles.Article.Version)
        |> Enum.filter(&(&1.version_action_type == :update))

      assert [:body, :subject] =
               Map.keys(updated_version.changes) |> Enum.sort()
    end
  end

  describe "belongs_to_actor option" do
    test "creates a relationship on the version" do
      assert length(AshPaperTrail.Resource.Info.belongs_to_actor(Posts.Post)) > 1

      relationships_on_version = Ash.Resource.Info.relationships(Posts.Post.Version)

      Enum.each(AshPaperTrail.Resource.Info.belongs_to_actor(Posts.Post), fn belongs_to_actor ->
        name = belongs_to_actor.name
        destination = belongs_to_actor.destination
        attribute_type = belongs_to_actor.attribute_type
        domain = belongs_to_actor.domain
        allow_nil? = belongs_to_actor.allow_nil?

        assert %Ash.Resource.Relationships.BelongsTo{
                 name: ^name,
                 destination: ^destination,
                 attribute_type: ^attribute_type,
                 source: AshPaperTrail.Test.Posts.Post.Version,
                 domain: ^domain,
                 allow_nil?: ^allow_nil?,
                 attribute_writable?: true
               } = Enum.find(relationships_on_version, &(&1.name == name))
      end)
    end

    test "sets a relationship on the versions" do
      user = Accounts.User.create!(%{name: "bob"})
      user_id = user.id

      news_feed = Accounts.NewsFeed.create!(%{organization: "ap"})
      news_feed_id = news_feed.id

      post = Posts.Post.create!(@valid_attrs, tenant: "acme", actor: news_feed)
      post = Posts.Post.publish!(post, tenant: "acme", actor: user)

      post =
        Posts.Post.update!(post, %{subject: "new subject"}, tenant: "acme", actor: "a string")

      post_id = post.id

      assert(
        [
          %{
            subject: "subject",
            body: "body",
            version_action_type: :create,
            version_source_id: ^post_id,
            user_id: nil,
            news_feed_id: ^news_feed_id
          },
          %{
            subject: "subject",
            body: "body",
            version_action_type: :update,
            version_source_id: ^post_id,
            user_id: ^user_id,
            news_feed_id: nil
          },
          %{
            subject: "new subject",
            body: "body",
            version_action_type: :update,
            version_source_id: ^post_id,
            user_id: nil,
            news_feed_id: nil
          }
        ] =
          Ash.read!(Posts.Post.Version, tenant: "acme")
          |> Enum.sort_by(& &1.version_inserted_at)
      )
    end
  end

  test "a new version is created on bulk_destroy" do
    assert %{subject: "subject", body: "body", id: post_id} =
             post = Posts.Post.create!(@valid_attrs, tenant: "acme")

    Ash.bulk_destroy!([post], :destroy, %{},
      strategy: [:stream, :atomic, :atomic_batches],
      return_errors?: true,
      tenant: "acme"
    )

    assert [
             %{
               subject: "subject",
               body: "body",
               version_action_type: :create,
               version_source_id: ^post_id
             },
             %{
               subject: "subject",
               body: "body",
               version_action_type: :destroy,
               version_source_id: ^post_id
             }
           ] =
             Ash.read!(Posts.Post.Version, tenant: "acme")
             |> Enum.sort_by(& &1.version_inserted_at)
  end
end
