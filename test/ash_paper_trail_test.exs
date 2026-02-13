# SPDX-FileCopyrightText: 2022 ash_paper_trail contributors <https://github.com/ash-project/ash_paper_trail/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshPaperTrailTest do
  @moduledoc false
  use ExUnit.Case
  require Ash.Query

  alias AshPaperTrail.Test.{Accounts, Articles, Posts}

  defp sort_versions(versions) do
    action_order = %{create: 0, publish: 1, update: 2, destroy: 3}
    type_order = %{create: 0, update: 1, destroy: 2}

    Enum.sort(versions, fn a, b ->
      cond do
        a.version_inserted_at != b.version_inserted_at ->
          DateTime.compare(a.version_inserted_at, b.version_inserted_at) == :lt

        a.version_action_type != b.version_action_type ->
          (type_order[a.version_action_type] || 99) < (type_order[b.version_action_type] || 99)

        true ->
          name_a = Map.get(a, :version_action_name, a.version_action_type)
          name_b = Map.get(b, :version_action_name, b.version_action_type)
          order_a = Map.get(action_order, name_a, 99)
          order_b = Map.get(action_order, name_b, 99)

          if order_a != order_b do
            order_a < order_b
          else
            # Same type and name (e.g. two creates) - use body then id
            body_a = Map.get(a, :body, "") |> to_string()
            body_b = Map.get(b, :body, "") |> to_string()

            if body_a != body_b do
              body_a < body_b
            else
              to_string(a.id) < to_string(b.id)
            end
          end
      end
    end)
  end

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
               Ash.read!(Posts.Post.Version, tenant: "acme") |> sort_versions()
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
               Ash.read!(Posts.Post.Version, tenant: "acme") |> sort_versions()
    end

    test "a new version is created on a bulk update with enumerable and after_transaction" do
      %{subject: "subject", body: "body", id: post_id} =
        post = Posts.Post.create!(@valid_attrs, tenant: "acme")

      %Ash.BulkResult{
        status: :success
      } =
        Ash.bulk_update!([post], :publish, %{},
          tenant: "acme",
          strategy: :stream,
          return_records?: true,
          return_errors?: true
        )

      assert [
               _,
               %{
                 changes: %{
                   published: true
                 },
                 version_action_type: :update,
                 version_action_name: :publish,
                 version_source_id: ^post_id
               }
             ] =
               Ash.read!(Posts.Post.Version, tenant: "acme") |> sort_versions()
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
               Ash.read!(Posts.Post.Version, tenant: "acme") |> sort_versions()
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

    test "the action inputs are stored correctly" do
      assert AshPaperTrail.Resource.Info.store_action_inputs?(Posts.StoreInputsPost) == true

      attrs =
        Map.merge(@valid_attrs, %{
          "secret" => "This will be redacted",
          "req_arg" => "This is required",
          "req_sensitive_arg" => "This is required and sensitive"
        })

      post = Posts.StoreInputsPost.create!(attrs, tenant: "acme")

      [created_version] =
        Ash.read!(Posts.StoreInputsPost.Version, tenant: "acme")

      assert %{
               version_action_inputs:
                 %{
                   author: %{first_name: "John", last_name: "Doe"},
                   body: "body",
                   tags: [%{tag: "ash"}, %{tag: "phoenix"}],
                   secret: "REDACTED",
                   subject: "subject",
                   req_arg: "This is required",
                   req_sensitive_arg: "REDACTED"
                 } = action_inputs
             } = created_version

      # Ensure that only passed attributes/arguments are stored
      assert not Map.has_key?(action_inputs, :id)
      assert not Map.has_key?(action_inputs, :published)
      assert not Map.has_key?(action_inputs, :opt_arg)
      assert not Map.has_key?(action_inputs, :opt_sensitive_arg)
      assert action_inputs.author |> Map.keys() |> Enum.count() == 2

      Enum.each(action_inputs.tags, fn tag ->
        assert tag |> Map.keys() |> Enum.count() == 1
      end)

      Posts.StoreInputsPost.update!(
        post,
        %{
          subject: "new subject",
          req_arg: "This is still required",
          req_sensitive_arg: "This will still be redacted",
          opt_arg: "This is optional",
          opt_sensitive_arg: "This will be redacted"
        },
        tenant: "acme"
      )

      [updated_version] =
        Ash.read!(Posts.StoreInputsPost.Version, tenant: "acme")
        |> Enum.filter(&(&1.version_action_name == :update))

      assert %{
               version_action_inputs: %{
                 subject: "new subject",
                 req_arg: "This is still required",
                 req_sensitive_arg: "REDACTED",
                 opt_arg: "This is optional",
                 opt_sensitive_arg: "REDACTED"
               }
             } = updated_version

      assert not Map.has_key?(updated_version.version_action_inputs, :id)
      assert not Map.has_key?(updated_version.version_action_inputs, :published)
      assert not Map.has_key?(updated_version.version_action_inputs, :tags)
      assert not Map.has_key?(updated_version.version_action_inputs, :author)
      assert not Map.has_key?(updated_version.version_action_inputs, :secret)
      assert not Map.has_key?(updated_version.version_action_inputs, :body)
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
               Ash.read!(Posts.Post.Version, tenant: "acme") |> sort_versions()
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
               Ash.read!(Posts.Post.Version, tenant: "acme") |> sort_versions()
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
               Ash.read!(Posts.Post.Version, tenant: "acme") |> sort_versions()
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

  describe "only_when_changed?" do
    test "when set to `true` no versions are generated when nothing has changed" do
      assert %{subject: "subject", body: "body", id: post_id} =
               post =
               Posts.UpsertPost.create!(%{subject: "subject", body: "body"}, tenant: "acme")

      assert %{subject: "subject", body: "body"} =
               Posts.UpsertPost.update!(post, %{subject: "subject", body: "body"}, tenant: "acme")

      assert [
               %{
                 subject: "subject",
                 body: "body",
                 version_action_type: :create,
                 version_source_id: ^post_id
               }
             ] =
               Ash.read!(Posts.UpsertPost.Version, tenant: "acme") |> sort_versions()
    end

    test "can be set to `false` to generate versions even when nothing has changed" do
      assert %{subject: "subject", body: "body", id: post_id} =
               post = Posts.BlogPost.create!(@valid_attrs, tenant: "acme")

      assert %{subject: "subject", body: "body"} =
               Posts.BlogPost.update!(post, %{subject: "subject", body: "body"}, tenant: "acme")

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
                 version_action_type: :update,
                 version_source_id: ^post_id
               }
             ] =
               Ash.read!(Posts.BlogPost.Version, tenant: "acme") |> sort_versions()
    end

    test "if set to `false` and the context `:skip_version_when_unchanged?` is set to `true`, a version is not created" do
      assert %{subject: "subject", body: "body", id: post_id} =
               post = Posts.BlogPost.create!(@valid_attrs, tenant: "acme")

      assert %{subject: "subject", body: "body"} =
               Posts.BlogPost.update!(post, %{subject: "subject", body: "body"},
                 tenant: "acme",
                 context: %{skip_version_when_unchanged?: true}
               )

      assert [
               %{
                 subject: "subject",
                 body: "body",
                 version_action_type: :create,
                 version_source_id: ^post_id
               }
             ] =
               Ash.read!(Posts.BlogPost.Version, tenant: "acme") |> sort_versions()
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
          Ash.read!(Posts.Post.Version, tenant: "acme") |> sort_versions()
      )
    end
  end

  test "a new version is created on bulk_destroy" do
    assert %{subject: "subject", body: "body", id: post_id} =
             post = Posts.Post.create!(@valid_attrs, tenant: "acme")

    Ash.bulk_destroy!([post], :destroy, %{},
      strategy: :atomic,
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
             Ash.read!(Posts.Post.Version, tenant: "acme") |> sort_versions()
  end

  describe ":primary_key_type options" do
    test ":id as as UUID" do
      assert AshPaperTrail.Resource.Info.primary_key_type(Posts.Post) == :uuid

      post = Posts.Post.create!(@valid_attrs, tenant: "acme")
      Posts.Post.update!(post, %{subject: "new subject"}, tenant: "acme")

      [updated_version] =
        Ash.read!(Posts.Post.Version, tenant: "acme")
        |> Enum.filter(&(&1.version_action_type == :update))

      uuid = updated_version.id
      assert {:ok, binary_uuid} = Ash.Type.dump_to_native(Ash.Type.UUID, uuid)
      assert {:ok, ^uuid} = Ash.Type.cast_input(Ash.Type.UUID, binary_uuid)
    end

    test ":id as UUID v7" do
      assert AshPaperTrail.Resource.Info.primary_key_type(Accounts.User) == :uuid_v7

      user = Accounts.User.create!(%{name: "name"})
      Accounts.User.update!(user, %{name: "new name"})

      [updated_version] =
        Ash.read!(Accounts.User.Version)
        |> Enum.filter(&(&1.version_action_type == :update))

      uuid_v7 = updated_version.id
      assert {:ok, binary_uuid_v7} = Ash.Type.dump_to_native(Ash.Type.UUIDv7, uuid_v7)
      assert {:ok, ^uuid_v7} = Ash.Type.cast_input(Ash.Type.UUIDv7, binary_uuid_v7)
    end
  end

  describe "ignore_actions" do
    test "no new version is created on destroy" do
      assert %{subject: "subject", body: "body"} =
               article = Articles.Article.create!("subject", "body")

      assert :ok = Articles.Article.destroy!(article)

      versions = Ash.read!(Articles.Article.Version) |> sort_versions()

      assert [
               %{
                 subject: "subject",
                 body: "body",
                 version_action_type: :create
               }
             ] = versions

      refute Enum.any?(versions, &(&1.version_action_type == :destroy))
    end
  end

  describe "sensitive_attributes" do
    test "when sensitive_attributes is set to display, they are versioned" do
      post =
        Posts.Post
        |> Ash.Changeset.for_create(:create, @valid_attrs)
        |> Ash.Changeset.force_change_attribute(:secret, "top secret data")
        |> Ash.Changeset.set_context(%{sensitive_attributes: :display})
        |> Ash.create!(tenant: "acme", load: [:paper_trail_versions])

      assert [version] = post.paper_trail_versions

      assert version.secret == "top secret data"
      assert version.changes[:secret] == "top secret data"
    end

    test "when sensitive_attributes are redacted, they are" do
      post =
        Posts.Post
        |> Ash.Changeset.for_create(:create, @valid_attrs)
        |> Ash.Changeset.force_change_attribute(:secret, "top secret data")
        |> Ash.Changeset.set_context(%{sensitive_attributes: :redact})
        |> Ash.create!(tenant: "acme", load: [:paper_trail_versions])

      assert [version] = post.paper_trail_versions

      refute version.secret
      assert version.changes[:secret] == "REDACTED"
    end

    test "when sensitive_attributes are ignored, they are" do
      post =
        Posts.Post
        |> Ash.Changeset.for_create(:create, @valid_attrs)
        |> Ash.Changeset.force_change_attribute(:secret, "top secret data")
        |> Ash.Changeset.set_context(%{sensitive_attributes: :ignore})
        |> Ash.create!(tenant: "acme", load: [:paper_trail_versions])

      assert [version] = post.paper_trail_versions

      refute version.secret
      refute is_map_key(version.changes, :secret)
    end
  end

  describe "ash_paper_trail_disabled? context" do
    test "no version is created on create when context ash_paper_trail_disabled? is true" do
      assert %{subject: "subject", body: "body", id: _post_id} =
               Posts.Post.create!(@valid_attrs,
                 tenant: "acme",
                 context: %{ash_paper_trail_disabled?: true}
               )

      assert [] = Ash.read!(Posts.Post.Version, tenant: "acme")
    end

    test "no version is created on update when context ash_paper_trail_disabled? is true" do
      assert %{subject: "subject", body: "body", id: _post_id} =
               post = Posts.Post.create!(@valid_attrs, tenant: "acme")

      assert [%{version_action_type: :create}] =
               Ash.read!(Posts.Post.Version, tenant: "acme")

      assert %{subject: "new subject", body: "new body"} =
               Posts.Post.update!(post, %{subject: "new subject", body: "new body"},
                 tenant: "acme",
                 context: %{ash_paper_trail_disabled?: true}
               )

      assert [%{version_action_type: :create}] =
               Ash.read!(Posts.Post.Version, tenant: "acme")
    end

    test "no version is created on destroy when context ash_paper_trail_disabled? is true" do
      assert %{subject: "subject", body: "body", id: _post_id} =
               post = Posts.Post.create!(@valid_attrs, tenant: "acme")

      assert :ok =
               Posts.Post.destroy!(post,
                 tenant: "acme",
                 context: %{ash_paper_trail_disabled?: true}
               )

      assert [%{version_action_type: :create}] =
               Ash.read!(Posts.Post.Version, tenant: "acme")
    end

    test "no version is created on bulk create when context ash_paper_trail_disabled? is true" do
      %Ash.BulkResult{status: :success} =
        Ash.bulk_create!([@valid_attrs], Posts.Post, :create,
          tenant: "acme",
          context: %{ash_paper_trail_disabled?: true}
        )

      assert [] = Ash.read!(Posts.Post.Version, tenant: "acme")
    end

    test "no version is created on bulk update when context ash_paper_trail_disabled? is true" do
      %{subject: "subject", body: "body", id: _post_id} =
        post = Posts.Post.create!(@valid_attrs, tenant: "acme")

      %Ash.BulkResult{status: :success} =
        Ash.bulk_update!([post], :update, %{subject: "new subject", body: "new body"},
          tenant: "acme",
          strategy: :stream,
          return_records?: true,
          return_errors?: true,
          context: %{ash_paper_trail_disabled?: true}
        )

      assert [%{version_action_type: :create}] =
               Ash.read!(Posts.Post.Version, tenant: "acme")
    end

    test "no version is created on bulk destroy when context ash_paper_trail_disabled? is true" do
      %{subject: "subject", body: "body", id: _post_id} =
        post = Posts.Post.create!(@valid_attrs, tenant: "acme")

      %Ash.BulkResult{status: :success} =
        Ash.bulk_destroy!([post], :destroy, %{},
          strategy: :stream,
          tenant: "acme",
          return_errors?: true,
          context: %{ash_paper_trail_disabled?: true}
        )

      assert [%{version_action_type: :create}] =
               Ash.read!(Posts.Post.Version, tenant: "acme")
    end

    test "no version is created when action has set_context(ash_paper_trail_disabled?: true)" do
      assert %{subject: "subject", body: "body", id: _post_id} =
               post = Posts.Post.create!(@valid_attrs, tenant: "acme")

      assert %{subject: "silent subject"} =
               Posts.Post.silent_update!(post, %{subject: "silent subject"}, tenant: "acme")

      assert [%{version_action_type: :create}] =
               Ash.read!(Posts.Post.Version, tenant: "acme")
    end

    test "versions are created when ash_paper_trail_disabled? is nil or false" do
      assert %{subject: "subject", body: "body", id: _post_id} =
               post = Posts.Post.create!(@valid_attrs, tenant: "acme")

      assert %{subject: "new subject"} =
               Posts.Post.update!(post, %{subject: "new subject"},
                 tenant: "acme",
                 context: %{ash_paper_trail_disabled?: false}
               )

      versions = Ash.read!(Posts.Post.Version, tenant: "acme") |> sort_versions()

      assert [
               %{version_action_type: :create},
               %{version_action_type: :update, subject: "new subject"}
             ] =
               versions
    end
  end

  describe "create_version_on_destroy?" do
    test "when create_version_on_destroy? is false, no version is created on destroy" do
      assert %{subject: "subject", body: "body", id: post_id} =
               post = Posts.NoDestroyVersionPost.create!(%{subject: "subject", body: "body"})

      assert :ok = Posts.NoDestroyVersionPost.destroy!(post)

      assert [
               %{
                 subject: "subject",
                 body: "body",
                 version_action_type: :create,
                 version_source_id: ^post_id
               }
             ] = Ash.read!(Posts.NoDestroyVersionPost.Version)

      refute Enum.any?(
               Ash.read!(Posts.NoDestroyVersionPost.Version),
               &(&1.version_action_type == :destroy)
             )
    end

    test "when create_version_on_destroy? is false, no version is created on bulk destroy with enumerable" do
      %{subject: "subject", body: "body", id: post_id} =
        post = Posts.NoDestroyVersionPost.create!(%{subject: "subject", body: "body"})

      %Ash.BulkResult{
        status: :success
      } =
        Ash.bulk_destroy!([post], :destroy, %{},
          strategy: :stream,
          return_errors?: true
        )

      assert [
               %{
                 subject: "subject",
                 body: "body",
                 version_action_type: :create,
                 version_source_id: ^post_id
               }
             ] = Ash.read!(Posts.NoDestroyVersionPost.Version)

      refute Enum.any?(
               Ash.read!(Posts.NoDestroyVersionPost.Version),
               &(&1.version_action_type == :destroy)
             )
    end

    test "when create_version_on_destroy? is false, no version is created on bulk destroy with query" do
      %{subject: "subject", body: "body", id: post_id} =
        Posts.NoDestroyVersionPost.create!(%{subject: "subject", body: "body"})

      %Ash.BulkResult{
        status: :success
      } =
        Posts.NoDestroyVersionPost
        |> Ash.Query.filter(id: post_id)
        |> Ash.bulk_destroy!(:destroy, %{},
          strategy: :stream,
          return_errors?: true
        )

      assert [
               %{
                 subject: "subject",
                 body: "body",
                 version_action_type: :create,
                 version_source_id: ^post_id
               }
             ] = Ash.read!(Posts.NoDestroyVersionPost.Version)

      refute Enum.any?(
               Ash.read!(Posts.NoDestroyVersionPost.Version),
               &(&1.version_action_type == :destroy)
             )
    end

    test "when create_version_on_destroy? is true (default), a version is created on destroy" do
      assert %{subject: "subject", body: "body", id: post_id} =
               post = Posts.Post.create!(@valid_attrs, tenant: "acme")

      assert :ok = Posts.Post.destroy!(post, tenant: "acme")

      versions =
        Ash.read!(Posts.Post.Version, tenant: "acme") |> sort_versions()

      assert [
               %{
                 version_action_type: :create,
                 version_source_id: ^post_id
               },
               %{
                 version_action_type: :destroy,
                 version_source_id: ^post_id
               }
             ] = versions
    end
  end

  describe "public_timestamps?" do
    test "when public_timestamps? is false, timestamps are not public on the version resource" do
      assert AshPaperTrail.Resource.Info.public_timestamps?(AshPaperTrail.Test.Articles.Article) ==
               true

      Ash.Resource.Info.attributes(AshPaperTrail.Test.Articles.Article)
      |> Enum.filter(&(&1.name in [:version_updated_at, :version_inserted_at]))
      |> Enum.each(&assert(&1.public? == false))
    end

    test "when public_timestamps? is true, timestamps are public on the version resource" do
      assert AshPaperTrail.Resource.Info.public_timestamps?(AshPaperTrail.Test.Posts.Post) ==
               false

      Ash.Resource.Info.attributes(AshPaperTrail.Test.Posts.Post)
      |> Enum.filter(&(&1.name in [:version_updated_at, :version_inserted_at]))
      |> Enum.each(&assert(&1.public? == true))
    end
  end

  describe "upsert operations" do
    test "upsert creates version when record doesn't exist" do
      assert %{subject: "subject", body: "body", id: post_id} =
               Posts.UpsertPost.upsert!(%{subject: "subject", body: "body"})

      assert [
               %{
                 subject: "subject",
                 body: "body",
                 version_action_type: :create,
                 version_source_id: ^post_id
               }
             ] = Ash.read!(Posts.UpsertPost.Version)
    end

    test "upsert with only_when_changed? true doesn't create version when record exists unchanged" do
      assert %{subject: "subject", body: "body", id: post_id} =
               Posts.UpsertPost.upsert!(%{subject: "subject", body: "body"})

      assert %{subject: "subject", body: "body"} =
               Posts.UpsertPost.upsert!(%{subject: "subject", body: "body"})

      assert [
               %{
                 subject: "subject",
                 body: "body",
                 version_action_type: :create,
                 version_source_id: ^post_id
               }
             ] = Ash.read!(Posts.UpsertPost.Version)
    end

    test "upsert with only_when_changed? true creates version when record exists but changes" do
      assert %{subject: "subject", body: "body", id: post_id} =
               Posts.UpsertPost.upsert!(%{subject: "subject", body: "body"})

      assert %{subject: "subject", body: "new body"} =
               Posts.UpsertPost.upsert!(%{subject: "subject", body: "new body"})

      assert [
               %{
                 subject: "subject",
                 body: "body",
                 version_action_type: :create,
                 version_source_id: ^post_id
               },
               %{
                 subject: "subject",
                 body: "new body",
                 version_action_type: :create,
                 version_source_id: ^post_id
               }
             ] =
               Ash.read!(Posts.UpsertPost.Version) |> sort_versions()
    end

    test "upsert with only_when_changed? false creates version even when unchanged" do
      assert %{subject: "subject", body: "body", id: post_id} =
               Posts.BlogPost.upsert!(%{subject: "subject", body: "body"}, tenant: "acme")

      assert %{subject: "subject", body: "body"} =
               Posts.BlogPost.upsert!(%{subject: "subject", body: "body"}, tenant: "acme")

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
                 version_action_type: :create,
                 version_source_id: ^post_id
               }
             ] =
               Ash.read!(Posts.BlogPost.Version, tenant: "acme") |> sort_versions()
    end

    test "upsert with skip_version_when_unchanged? context doesn't create version when unchanged" do
      assert %{subject: "subject", body: "body", id: post_id} =
               Posts.BlogPost.upsert!(%{subject: "subject", body: "body"}, tenant: "acme")

      assert %{subject: "subject", body: "body"} =
               Posts.BlogPost.upsert!(
                 %{subject: "subject", body: "body"},
                 tenant: "acme",
                 context: %{skip_version_when_unchanged?: true}
               )

      assert [
               %{
                 subject: "subject",
                 body: "body",
                 version_action_type: :create,
                 version_source_id: ^post_id
               }
             ] = Ash.read!(Posts.BlogPost.Version, tenant: "acme")
    end
  end
end
