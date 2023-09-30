defmodule AshPaperTrailTest do
  use ExUnit.Case

  alias AshPaperTrail.Test.{Posts, Articles}

  @valid_attrs %{
    subject: "subject",
    body: "body",
    secret: "password",
    author: %{first_name: "John", last_name: "Doe"},
    tags: [%{tag: "ash"}, %{tag: "phoenix"}]
  }
  describe "operations over resource api (without a registry)" do
    test "creates work as normal" do
      assert %{subject: "subject", body: "body"} =
               Posts.Post.create!(@valid_attrs, tenant: "acme")

      assert [%{subject: "subject", body: "body"}] = Posts.Post.read!(tenant: "acme")
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

    test "existing allow mfa is called" do
      Posts.Post.create!(@valid_attrs, tenant: "acme")
      assert_received :existing_allow_mfa_called
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
                   author: %{autogenerated_id: _author_id, first_name: "John", last_name: "Doe"},
                   tags: [
                     %{tag: "ash", autogenerated_id: _tag_id1},
                     %{tag: "phoenix", autogenerated_id: _tag_id2}
                   ]
                 },
                 version_action_type: :create,
                 version_action_name: :create,
                 version_source_id: ^post_id
               }
             ] =
               Articles.Api.read!(Posts.Post.Version, tenant: "acme")
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
               Posts.Api.read!(Posts.Post.Version, tenant: "acme")
               |> Enum.sort_by(& &1.version_inserted_at)
    end

    test "the action name is stored" do
      assert AshPaperTrail.Resource.Info.store_action_name?(Posts.Post) == true

      post = Posts.Post.create!(@valid_attrs, tenant: "acme")
      Posts.Post.publish!(post, %{}, tenant: "acme")

      [publish_version] =
        Posts.Api.read!(Posts.Post.Version, tenant: "acme")
        |> Enum.filter(&(&1.version_action_type == :update))

      assert %{version_action_type: :update, version_action_name: :publish} = publish_version
    end

    test "the new version only includes changes in :changes_only mode" do
      assert AshPaperTrail.Resource.Info.change_tracking_mode(Posts.Post) == :changes_only

      post = Posts.Post.create!(@valid_attrs, tenant: "acme")
      Posts.Post.update!(post, %{subject: "new subject"}, tenant: "acme")

      [updated_version] =
        Posts.Api.read!(Posts.Post.Version, tenant: "acme")
        |> Enum.filter(&(&1.version_action_type == :update))

      assert [:subject] = Map.keys(updated_version.changes)
    end

    test "the new version only includes changes in :snapshot mode" do
      assert AshPaperTrail.Resource.Info.change_tracking_mode(Articles.Article) == :snapshot

      article = Articles.Article.create!("subject", "body")
      Articles.Article.update!(article, %{subject: "new subject"})

      [updated_version] =
        Articles.Api.read!(Articles.Article.Version)
        |> Enum.filter(&(&1.version_action_type == :update))

      assert [:body, :subject] =
               Map.keys(updated_version.changes) |> Enum.sort()
    end

    test "the new version only includes changes in :full_diff mode" do
      assert AshPaperTrail.Resource.Info.change_tracking_mode(Posts.Page) == :full_diff

      page = Posts.Page.create!(%{subject: "subject", body: "body"}, tenant: "acme")

      Posts.Page.update!(page, %{subject: "new subject", author: %{first_name: "bob"}},
        tenant: "acme"
      )

      [updated_version] =
        Posts.Api.read!(Posts.Page.Version, tenant: "acme")
        |> Enum.filter(&(&1.version_action_type == :update))

      assert %{
               subject: %{from: "subject", to: "new subject"},
               body: %{unchanged: "body"},
               author: %{
                 from: nil,
                 to: %{first_name: "bob", last_name: nil, autogenerated_id: _id}
               },
               published: %{unchanged: false},
               secret: %{unchanged: nil},
               tags: %{unchanged: []},
               tenant: %{unchanged: "acme"}
             } = updated_version.changes

      assert [:author, :body, :published, :secret, :subject, :tags, :tenant] =
               Map.keys(updated_version.changes) |> Enum.sort()
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
               Posts.Api.read!(Posts.Post.Version, tenant: "acme")
               |> Enum.sort_by(& &1.version_inserted_at)
    end
  end

  describe "operations over resource with an Api Registry (Not Recommended)" do
    test "creates work as normal" do
      assert %{subject: "subject", body: "body"} = Articles.Article.create!("subject", "body")
      assert [%{subject: "subject", body: "body"}] = Articles.Article.read!()
    end

    test "updates work as normal" do
      assert %{subject: "subject", body: "body"} =
               post = Articles.Article.create!("subject", "body")

      assert %{subject: "new subject", body: "new body"} =
               Articles.Article.update!(post, %{subject: "new subject", body: "new body"})

      assert [%{subject: "new subject", body: "new body"}] = Articles.Article.read!()
    end

    test "destroys work as normal" do
      assert %{subject: "subject", body: "body"} =
               post = Articles.Article.create!("subject", "body")

      assert :ok = Articles.Article.destroy!(post)

      assert [] = Articles.Article.read!()
    end
  end
end
