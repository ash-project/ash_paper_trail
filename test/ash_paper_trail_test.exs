defmodule AshPaperTrailTest do
  use ExUnit.Case

  alias AshPaperTrail.Test.{Api, Post, Post.Version}

  describe "operations over resource" do
    test "creates work as normal" do
      assert %{subject: "subject", body: "body"} = Post.create!("subject", "body")
      assert [%{subject: "subject", body: "body"}] = Post.read!()
    end

    test "updates work as normal" do
      assert %{subject: "subject", body: "body"} = post = Post.create!("subject", "body")

      assert %{subject: "new subject", body: "new body"} =
               Post.update!(post, %{subject: "new subject", body: "new body"})

      assert [%{subject: "new subject", body: "new body"}] = Post.read!()
    end

    test "destroys work as normal" do
      assert %{subject: "subject", body: "body"} = post = Post.create!("subject", "body")

      assert :ok = Post.destroy!(post)

      assert [] = Post.read!()
    end
  end

  describe "version resource" do
    test "a new version is created on create" do
      assert %{subject: "subject", body: "body", id: post_id} = Post.create!("subject", "body")

      assert [
               %{
                 subject: "subject",
                 body: "body",
                 version_action_type: :create,
                 version_source_id: ^post_id
               }
             ] = Api.read!(Version)
    end

    test "a new version is created on update" do
      assert %{subject: "subject", body: "body", id: post_id} =
               post = Post.create!("subject", "body")

      assert %{subject: "new subject", body: "new body"} =
               Post.update!(post, %{subject: "new subject", body: "new body"})

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
             ] = Api.read!(Version) |> Enum.sort_by(& &1.version_inserted_at)
    end

    test "a new version is created on destroy" do
      assert %{subject: "subject", body: "body", id: post_id} =
               post = Post.create!("subject", "body")

      assert :ok = Post.destroy!(post)

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
             ] = Api.read!(Version) |> Enum.sort_by(& &1.version_inserted_at)
    end
  end
end
