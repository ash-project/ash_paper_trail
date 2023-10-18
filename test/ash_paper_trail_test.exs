defmodule AshPaperTrailTest do
  use ExUnit.Case

  alias AshPaperTrail.Test.{Posts, Articles, Accounts}

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
                     %{tag: "ash", id: _tag_id1},
                     %{tag: "phoenix", id: _tag_id2}
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

  describe "changes in :changes_only mode" do
    test "the changes only includes attributes that changed" do
      assert AshPaperTrail.Resource.Info.change_tracking_mode(Posts.Post) == :changes_only

      post = Posts.Post.create!(@valid_attrs, tenant: "acme")
      Posts.Post.update!(post, %{subject: "new subject"}, tenant: "acme")

      [updated_version] =
        Posts.Api.read!(Posts.Post.Version, tenant: "acme")
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
        Articles.Api.read!(Articles.Article.Version)
        |> Enum.filter(&(&1.version_action_type == :update))

      assert [:body, :subject] =
               Map.keys(updated_version.changes) |> Enum.sort()
    end
  end

  describe "changes in :full_diff mode" do
    setup do
      assert AshPaperTrail.Resource.Info.change_tracking_mode(Posts.Page) == :full_diff
      [resource: Posts.Page, api: Posts.Api, version_resource: Posts.Page.Version]
    end

    test "create a new resource", ctx do
      ctx.resource.create!(%{subject: "subject", body: "body"})

      assert %{
               subject: %{to: "subject"},
               body: %{to: "body"},
               author: %{to: nil},
               published: %{to: false},
               secret: %{to: nil},
               tags: %{to: []},
               seo_map: %{to: nil},
               views: %{to: 0}
             } = last_version_changes(ctx.api, ctx.version_resource)
    end

    test "create a new resource with embedded resource and map", ctx do
      ctx.resource.create!(%{
        subject: "subject",
        body: "body",
        author: %{first_name: "Bob"},
        seo_map: %{keywords: []}
      })

      assert %{
               subject: %{to: "subject"},
               body: %{to: "body"},
               author: %{
                 created: %{
                   first_name: %{to: "Bob"},
                   last_name: %{to: nil},
                   autogenerated_id: %{to: _id}
                 }
               },
               seo_map: %{to: %{keywords: []}},
               published: %{to: false},
               secret: %{to: nil},
               tags: %{to: []}
             } = last_version_changes(ctx.api, ctx.version_resource)
    end

    test "update a resource", ctx do
      ctx.resource.create!(%{subject: "subject", body: "body"})
      |> ctx.resource.update!(%{subject: "new subject", views: 1})

      assert %{
               subject: %{to: "new subject"},
               body: %{unchanged: "body"},
               author: %{unchanged: nil},
               published: %{unchanged: false},
               secret: %{unchanged: nil},
               tags: %{unchanged: []},
               seo_map: %{unchanged: nil},
               views: %{from: 0, to: 1}
             } = last_version_changes(ctx.api, ctx.version_resource)
    end

    test "add an embedded resource and map", ctx do
      ctx.resource.create!(%{subject: "subject", body: "body"})
      |> ctx.resource.update!(%{author: %{first_name: "Bob"}, seo_map: %{keywords: ["Bob"]}})

      assert %{
               subject: %{unchanged: "subject"},
               body: %{unchanged: "body"},
               author: %{
                 created: %{
                   first_name: %{to: "Bob"},
                   last_name: %{to: nil},
                   autogenerated_id: %{to: _id}
                 }
               },
               seo_map: %{to: %{keywords: ["Bob"]}},
               published: %{unchanged: false},
               secret: %{unchanged: nil},
               tags: %{unchanged: []}
             } = last_version_changes(ctx.api, ctx.version_resource)
    end

    test "update an embedded resource and map", ctx do
      ctx.resource.create!(%{
        subject: "subject",
        body: "body",
        author: %{first_name: "Bob"},
        seo_map: %{author: "Bob"}
      })
      |> ctx.resource.update!(%{
        author: %{first_name: "Bob", last_name: "Jones"},
        seo_map: %{keywords: ["Bob"]}
      })

      assert %{
               subject: %{unchanged: "subject"},
               body: %{unchanged: "body"},
               author: %{
                 updated: %{
                   first_name: %{unchanged: "Bob"},
                   last_name: %{from: nil, to: "Jones"},
                   autogenerated_id: %{unchanged: _id}
                 }
               },
               seo_map: %{from: %{author: "Bob"}, to: %{keywords: ["Bob"]}},
               published: %{unchanged: false},
               secret: %{unchanged: nil},
               tags: %{unchanged: []}
             } = last_version_changes(ctx.api, ctx.version_resource)
    end

    test "update a resource without updating the embedded resource", ctx do
      ctx.resource.create!(%{
        subject: "subject",
        body: "body",
        author: %{first_name: "Bob"},
        seo_map: %{keywords: ["Bob"]}
      })
      |> ctx.resource.update!(%{subject: "new subject"})

      assert %{
               subject: %{to: "new subject"},
               body: %{unchanged: "body"},
               author: %{
                 unchanged: %{
                   first_name: %{unchanged: "Bob"},
                   last_name: %{unchanged: nil}
                 }
               },
               seo_map: %{unchanged: %{keywords: ["Bob"]}},
               published: %{unchanged: false},
               secret: %{unchanged: nil},
               tags: %{unchanged: []}
             } = last_version_changes(ctx.api, ctx.version_resource)
    end

    test "remove an embedded resource and map", ctx do
      ctx.resource.create!(%{
        subject: "subject",
        body: "body",
        author: %{first_name: "Bob"},
        seo_map: %{keywords: ["Bob"]}
      })
      |> ctx.resource.update!(%{author: nil, seo_map: nil})

      assert %{
               subject: %{unchanged: "subject"},
               body: %{unchanged: "body"},
               author: %{
                 destroyed: %{
                   first_name: %{from: "Bob"},
                   last_name: %{from: nil},
                   autogenerated_id: %{from: _id}
                 }
               },
               seo_map: %{from: %{keywords: ["Bob"]}, to: nil},
               published: %{unchanged: false},
               secret: %{unchanged: nil},
               tags: %{unchanged: []}
             } = last_version_changes(ctx.api, ctx.version_resource)
    end

    test "destroy with an embedded resource and map", ctx do
      ctx.resource.create!(%{
        subject: "subject",
        body: "body",
        author: %{first_name: "Bob"},
        seo_map: %{keywords: ["Bob"]}
      })
      |> ctx.resource.destroy!()

      assert %{
               subject: %{unchanged: "subject"},
               body: %{unchanged: "body"},
               author: %{
                 unchanged: %{
                   autogenerated_id: %{unchanged: _auto_id},
                   first_name: %{unchanged: "Bob"},
                   last_name: %{unchanged: nil}
                 }
               },
               seo_map: %{unchanged: %{keywords: ["Bob"]}},
               published: %{unchanged: false},
               secret: %{unchanged: nil},
               tags: %{unchanged: []}
             } = last_version_changes(ctx.api, ctx.version_resource)
    end

    test "create a new resource with embedded array", ctx do
      ctx.resource.create!(%{
        subject: "subject",
        body: "body",
        tags: [%{tag: "Ash"}, %{tag: "Phoenix"}],
        lucky_numbers: [7, 9]
      })

      assert %{
               subject: %{to: "subject"},
               body: %{to: "body"},
               author: %{to: nil},
               seo_map: %{to: nil},
               published: %{to: false},
               secret: %{to: nil},
               tags: %{
                 to: [
                   %{created: %{tag: %{to: "Ash"}, id: %{to: _id1}}, index: %{to: 0}},
                   %{created: %{tag: %{to: "Phoenix"}, id: %{to: _id2}}, index: %{to: 1}}
                 ]
               },
               lucky_numbers: %{to: [7, 9]}
             } = last_version_changes(ctx.api, ctx.version_resource)
    end

    test "update resource by adding to an array", ctx do
      res =
        ctx.resource.create!(%{
          subject: "subject",
          body: "body",
          tags: [%{tag: "Ash"}, %{tag: "Phoenix"}],
          lucky_numbers: [7, 9]
        })

      %{tags: [%{id: ash_id}, %{id: phx_id}]} = res

      ctx.resource.update!(res, %{
        tags: [%{tag: "Ash", id: ash_id}, %{tag: "Nerves"}, %{tag: "Phx", id: phx_id}],
        lucky_numbers: [7, 8, 9]
      })

      assert %{
               tags: %{
                 to: [
                   %{
                     unchanged: %{tag: %{unchanged: "Ash"}, id: %{unchanged: ^ash_id}},
                     index: %{unchanged: 0}
                   },
                   %{created: %{tag: %{to: "Nerves"}, id: %{to: _nerves_id}}, index: %{to: 1}},
                   %{
                     updated: %{tag: %{to: "Phx"}, id: %{unchanged: ^phx_id}},
                     index: %{to: 2, from: 1}
                   }
                 ]
               },
               lucky_numbers: %{from: [7, 9], to: [7, 8, 9]}
             } = last_version_changes(ctx.api, ctx.version_resource)
    end

    test "update resource by adding to an empty array", ctx do
      res =
        ctx.resource.create!(%{
          subject: "subject",
          body: "body",
          tags: [],
          lucky_numbers: []
        })

      ctx.resource.update!(res, %{
        tags: [%{tag: "Ash"}],
        lucky_numbers: [7]
      })

      assert %{
               tags: %{
                 to: [
                   %{created: %{tag: %{to: "Ash"}, id: %{to: _ash_id}}, index: %{to: 0}}
                 ]
               },
               lucky_numbers: %{from: [], to: [7]}
             } = last_version_changes(ctx.api, ctx.version_resource)
    end

    test "update resource by removing from an array", ctx do
      res =
        ctx.resource.create!(%{
          subject: "subject",
          body: "body",
          tags: [%{tag: "Ash"}],
          lucky_numbers: [7]
        })

      ctx.resource.update!(res, %{
        tags: [],
        lucky_numbers: []
      })

      assert %{
               tags: %{
                 to: [
                   %{destroyed: %{tag: %{from: "Ash"}, id: %{from: _ash_id}}, index: %{from: 0}}
                 ]
               },
               lucky_numbers: %{from: [7], to: []}
             } = last_version_changes(ctx.api, ctx.version_resource)
    end

    test "making a composite array nil", ctx do
      res =
        ctx.resource.create!(%{
          subject: "subject",
          body: "body",
          tags: [%{tag: "Ash"}],
          lucky_numbers: [7]
        })

      ctx.resource.update!(res, %{
        tags: nil,
        lucky_numbers: nil
      })

      assert %{
               tags: %{
                 to: [
                   %{destroyed: %{tag: %{from: "Ash"}, id: %{from: _ash_id}}, index: %{from: 0}}
                 ]
               },
               lucky_numbers: %{from: [7], to: nil}
             } = last_version_changes(ctx.api, ctx.version_resource)
    end

    test "update resource by creating with a union", ctx do
      ctx.resource.create!(%{
        subject: "subject",
        body: "body",
        moderator_reaction: 100
      })

      assert %{
               moderator_reaction: %{to: %{type: "score", value: 100}}
             } = last_version_changes(ctx.api, ctx.version_resource)
    end

    #   test "update resource by updating a union", ctx do
    #     res = ctx.resource.create!(%{
    #       subject: "subject",
    #       body: "body",
    #       moderator_reaction: 100
    #     })

    #     ctx.resource.update!(res, %{
    #       moderator_reaction: %{type: :comment, value: "like"}
    #     })

    #   assert %{
    #            moderator_reaction: %{from: %{type: "score", value: 100}, to: %{type: "comment", value: "like"}},
    #          } = last_version_changes(ctx.api, ctx.version_resource)
    # end

    test "update resource by creating with an array of unions", ctx do
        ctx.resource.create!(%{
          subject: "subject",
          body: "body",
          reactions: [2, "like"]
        })

      assert %{
               reactions: %{
                 to: [%{to: %{type: "score", value: 2}}, %{to: %{type: "comment", value: "like"}}]
               }
             } = last_version_changes(ctx.api, ctx.version_resource)
    end

    # test "update resource by creating with a union embedded resource" do
    # end

    # test "update resource by updating a union embedded resource" do
    # end

    # test "update resource by removing a union embedded resource" do
    # end

    # test "update resource by creating with a union resource to an embedded array" do
    # end

    # test "update resource by updating with a union resource to an embedded array" do
    # end

    # test "update resource by destroying with a union resource to an embedded array" do
    # end
  end

  describe "belongs_to_actor option" do
    test "creates a relationship on the version" do
      assert length(AshPaperTrail.Resource.Info.belongs_to_actor(Posts.Post)) > 1

      relationships_on_version = Ash.Resource.Info.relationships(Posts.Post.Version)

      Enum.each(AshPaperTrail.Resource.Info.belongs_to_actor(Posts.Post), fn belongs_to_actor ->
        name = belongs_to_actor.name
        destination = belongs_to_actor.destination
        attribute_type = belongs_to_actor.attribute_type
        api = belongs_to_actor.api
        allow_nil? = belongs_to_actor.allow_nil?

        assert %Ash.Resource.Relationships.BelongsTo{
                 name: ^name,
                 destination: ^destination,
                 attribute_type: ^attribute_type,
                 source: AshPaperTrail.Test.Posts.Post.Version,
                 api: ^api,
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
          Posts.Api.read!(Posts.Post.Version, tenant: "acme")
          |> Enum.sort_by(& &1.version_inserted_at)
      )
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

  defp last_version_changes(api, version_resource) do
    api.read!(version_resource)
    |> Enum.sort_by(& &1.version_inserted_at)
    |> List.last()
    |> Map.get(:changes)
  end
end
