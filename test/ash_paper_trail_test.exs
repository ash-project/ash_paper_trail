defmodule AshPaperTrailTest do
  use ExUnit.Case

  alias AshPaperTrail.Test.{Posts, Articles}

  describe "operations over resource with an Api Registry" do
    test "creates work as normal" do
      assert %{subject: "subject", body: "body"} = Posts.Post.create!("subject", "body")
      assert [%{subject: "subject", body: "body"}] = Posts.Post.read!()
    end

    test "updates work as normal" do
      assert %{subject: "subject", body: "body"} = post = Posts.Post.create!("subject", "body")

      assert %{subject: "new subject", body: "new body"} =
               Posts.Post.update!(post, %{subject: "new subject", body: "new body"})

      assert [%{subject: "new subject", body: "new body"}] = Posts.Post.read!()
    end

    test "destroys work as normal" do
      assert %{subject: "subject", body: "body"} = post = Posts.Post.create!("subject", "body")

      assert :ok = Posts.Post.destroy!(post)

      assert [] = Posts.Post.read!()
    end
  end

  describe "operations over resource api without a registry" do
    test "creates work as normal" do
      assert %{subject: "subject", body: "body"} =
               Articles.Article.create!("subject", "body", tenant: "acme")

      assert [%{subject: "subject", body: "body"}] = Articles.Article.read!(tenant: "acme")
    end

    test "updates work as normal" do
      assert %{subject: "subject", body: "body", tenant: "acme"} =
               post = Articles.Article.create!("subject", "body", tenant: "acme")

      assert %{subject: "new subject", body: "new body"} =
               Articles.Article.update!(post, %{subject: "new subject", body: "new body"})

      assert [%{subject: "new subject", body: "new body"}] =
               Articles.Article.read!(tenant: "acme")
    end

    test "destroys work as normal" do
      assert %{subject: "subject", body: "body", tenant: "acme"} =
               post = Articles.Article.create!("subject", "body", tenant: "acme")

      assert :ok = Articles.Article.destroy!(post)

      assert [] = Articles.Article.read!(tenant: "acme")
    end

    test "existing allow mfa is called" do
      Articles.Article.create!("subject", "body", tenant: "acme")
      assert_received :existing_allow_mfa_called
    end
  end

  describe "version resource" do
    test "a new version is created on create" do
      assert %{subject: "subject", body: "body", id: post_id} =
               Posts.Post.create!("subject", "body")

      assert [
               %{
                 subject: "subject",
                 body: "body",
                 version_action_type: :create,
                 version_source_id: ^post_id
               }
             ] = Posts.Api.read!(Posts.Post.Version)
    end

    test "a new version is created on update" do
      assert %{subject: "subject", body: "body", id: post_id} =
               post = Posts.Post.create!("subject", "body")

      assert %{subject: "new subject", body: "new body"} =
               Posts.Post.update!(post, %{subject: "new subject", body: "new body"})

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
             ] = Posts.Api.read!(Posts.Post.Version) |> Enum.sort_by(& &1.version_inserted_at)
    end

    test "a new version is created on destroy" do
      assert %{subject: "subject", body: "body", id: post_id} =
               post = Posts.Post.create!("subject", "body")

      assert :ok = Posts.Post.destroy!(post)

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
             ] = Posts.Api.read!(Posts.Post.Version) |> Enum.sort_by(& &1.version_inserted_at)
    end
  end
end
