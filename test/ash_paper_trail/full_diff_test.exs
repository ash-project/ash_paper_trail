defmodule AshPaperTrail.FullDiffTest do
  use ExUnit.Case

  alias AshPaperTrail.Test.{Posts, Articles, Accounts}
  import TestHelper

  setup do
    assert AshPaperTrail.Resource.Info.change_tracking_mode(Posts.FullDiffPost) == :full_diff
    [resource: Posts.FullDiffPost, api: Posts.Api, version_resource: Posts.FullDiffPost.Version]
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

  test "update a resource", ctx do
    ctx.resource.create!(%{subject: "subject", body: "body"})
    |> ctx.resource.update!(%{subject: "new subject", views: 1, seo_map: %{keywords: ["ash"]}})

    assert %{
             subject: %{to: "new subject", from: "subject"},
             body: %{unchanged: "body"},
             author: %{unchanged: nil},
             published: %{unchanged: false},
             secret: %{unchanged: nil},
             tags: %{unchanged: []},
             seo_map: %{to: %{keywords: ["ash"]}, from: nil},
             source: %{unchanged: nil},
             views: %{from: 0, to: 1}
           } = last_version_changes(ctx.api, ctx.version_resource)
  end

  describe "tracking an embedded resource" do
    test "create a new resource with embedded resource and map", ctx do
      ctx.resource.create!(%{
        author: %{first_name: "Bob"}
      })

      assert %{
               author: %{
                 created: %{
                   first_name: %{to: "Bob"},
                   last_name: %{to: nil},
                   autogenerated_id: %{to: _id}
                 }
               }
             } = last_version_changes(ctx.api, ctx.version_resource)
    end
  end

  # test "add an embedded resource and map", ctx do
  #   ctx.resource.create!(%{subject: "subject", body: "body"})
  #   |> ctx.resource.update!(%{author: %{first_name: "Bob"}, seo_map: %{keywords: ["Bob"]}})

  #   assert %{
  #            subject: %{unchanged: "subject"},
  #            body: %{unchanged: "body"},
  #            author: %{
  #              created: %{
  #                first_name: %{to: "Bob"},
  #                last_name: %{to: nil},
  #                autogenerated_id: %{to: _id}
  #              }
  #            },
  #            seo_map: %{to: %{keywords: ["Bob"]}},
  #            published: %{unchanged: false},
  #            secret: %{unchanged: nil},
  #            tags: %{unchanged: []}
  #          } = last_version_changes(ctx.api, ctx.version_resource)
  # end

  # test "update an embedded resource and map", ctx do
  #   ctx.resource.create!(%{
  #     subject: "subject",
  #     body: "body",
  #     author: %{first_name: "Bob"},
  #     seo_map: %{author: "Bob"}
  #   })
  #   |> ctx.resource.update!(%{
  #     author: %{first_name: "Bob", last_name: "Jones"},
  #     seo_map: %{keywords: ["Bob"]}
  #   })

  #   assert %{
  #            subject: %{unchanged: "subject"},
  #            body: %{unchanged: "body"},
  #            author: %{
  #              updated: %{
  #                first_name: %{unchanged: "Bob"},
  #                last_name: %{from: nil, to: "Jones"},
  #                autogenerated_id: %{unchanged: _id}
  #              }
  #            },
  #            seo_map: %{from: %{author: "Bob"}, to: %{keywords: ["Bob"]}},
  #            published: %{unchanged: false},
  #            secret: %{unchanged: nil},
  #            tags: %{unchanged: []}
  #          } = last_version_changes(ctx.api, ctx.version_resource)
  # end

  # test "update a resource without updating the embedded resource", ctx do
  #   ctx.resource.create!(%{
  #     subject: "subject",
  #     body: "body",
  #     author: %{first_name: "Bob"},
  #     seo_map: %{keywords: ["Bob"]}
  #   })
  #   |> ctx.resource.update!(%{subject: "new subject"})

  #   assert %{
  #            subject: %{to: "new subject"},
  #            body: %{unchanged: "body"},
  #            author: %{
  #              unchanged: %{
  #                first_name: %{unchanged: "Bob"},
  #                last_name: %{unchanged: nil}
  #              }
  #            },
  #            seo_map: %{unchanged: %{keywords: ["Bob"]}},
  #            published: %{unchanged: false},
  #            secret: %{unchanged: nil},
  #            tags: %{unchanged: []}
  #          } = last_version_changes(ctx.api, ctx.version_resource)
  # end

  # test "remove an embedded resource and map", ctx do
  #   ctx.resource.create!(%{
  #     subject: "subject",
  #     body: "body",
  #     author: %{first_name: "Bob"},
  #     seo_map: %{keywords: ["Bob"]}
  #   })
  #   |> ctx.resource.update!(%{author: nil, seo_map: nil})

  #   assert %{
  #            subject: %{unchanged: "subject"},
  #            body: %{unchanged: "body"},
  #            author: %{
  #              destroyed: %{
  #                first_name: %{from: "Bob"},
  #                last_name: %{from: nil},
  #                autogenerated_id: %{from: _id}
  #              }
  #            },
  #            seo_map: %{from: %{keywords: ["Bob"]}, to: nil},
  #            published: %{unchanged: false},
  #            secret: %{unchanged: nil},
  #            tags: %{unchanged: []}
  #          } = last_version_changes(ctx.api, ctx.version_resource)
  # end

  # test "destroy with an embedded resource and map", ctx do
  #   ctx.resource.create!(%{
  #     subject: "subject",
  #     body: "body",
  #     author: %{first_name: "Bob"},
  #     seo_map: %{keywords: ["Bob"]}
  #   })
  #   |> ctx.resource.destroy!()

  #   assert %{
  #            subject: %{unchanged: "subject"},
  #            body: %{unchanged: "body"},
  #            author: %{
  #              unchanged: %{
  #                autogenerated_id: %{unchanged: _auto_id},
  #                first_name: %{unchanged: "Bob"},
  #                last_name: %{unchanged: nil}
  #              }
  #            },
  #            seo_map: %{unchanged: %{keywords: ["Bob"]}},
  #            published: %{unchanged: false},
  #            secret: %{unchanged: nil},
  #            tags: %{unchanged: []}
  #          } = last_version_changes(ctx.api, ctx.version_resource)
  # end

  # test "create a new resource with embedded array", ctx do
  #   ctx.resource.create!(%{
  #     subject: "subject",
  #     body: "body",
  #     tags: [%{tag: "Ash"}, %{tag: "Phoenix"}],
  #     lucky_numbers: [7, 9]
  #   })

  #   assert %{
  #            subject: %{to: "subject"},
  #            body: %{to: "body"},
  #            author: %{to: nil},
  #            seo_map: %{to: nil},
  #            published: %{to: false},
  #            secret: %{to: nil},
  #            tags: %{
  #              to: [
  #                %{created: %{tag: %{to: "Ash"}, id: %{to: _id1}}, index: %{to: 0}},
  #                %{created: %{tag: %{to: "Phoenix"}, id: %{to: _id2}}, index: %{to: 1}}
  #              ]
  #            },
  #            lucky_numbers: %{to: [7, 9]}
  #          } = last_version_changes(ctx.api, ctx.version_resource)
  # end

  # test "update resource by adding to an array", ctx do
  #   res =
  #     ctx.resource.create!(%{
  #       subject: "subject",
  #       body: "body",
  #       tags: [%{tag: "Ash"}, %{tag: "Phoenix"}],
  #       lucky_numbers: [7, 9]
  #     })

  #   %{tags: [%{id: ash_id}, %{id: phx_id}]} = res

  #   ctx.resource.update!(res, %{
  #     tags: [%{tag: "Ash", id: ash_id}, %{tag: "Nerves"}, %{tag: "Phx", id: phx_id}],
  #     lucky_numbers: [7, 8, 9]
  #   })

  #   assert %{
  #            tags: %{
  #              to: [
  #                %{
  #                  unchanged: %{tag: %{unchanged: "Ash"}, id: %{unchanged: ^ash_id}},
  #                  index: %{unchanged: 0}
  #                },
  #                %{created: %{tag: %{to: "Nerves"}, id: %{to: _nerves_id}}, index: %{to: 1}},
  #                %{
  #                  updated: %{tag: %{to: "Phx"}, id: %{unchanged: ^phx_id}},
  #                  index: %{to: 2, from: 1}
  #                }
  #              ]
  #            },
  #            lucky_numbers: %{from: [7, 9], to: [7, 8, 9]}
  #          } = last_version_changes(ctx.api, ctx.version_resource)
  # end

  # test "update resource by adding to an empty array", ctx do
  #   res =
  #     ctx.resource.create!(%{
  #       subject: "subject",
  #       body: "body",
  #       tags: [],
  #       lucky_numbers: []
  #     })

  #   ctx.resource.update!(res, %{
  #     tags: [%{tag: "Ash"}],
  #     lucky_numbers: [7]
  #   })

  #   assert %{
  #            tags: %{
  #              to: [
  #                %{created: %{tag: %{to: "Ash"}, id: %{to: _ash_id}}, index: %{to: 0}}
  #              ]
  #            },
  #            lucky_numbers: %{from: [], to: [7]}
  #          } = last_version_changes(ctx.api, ctx.version_resource)
  # end

  # test "update resource by removing from an array", ctx do
  #   res =
  #     ctx.resource.create!(%{
  #       subject: "subject",
  #       body: "body",
  #       tags: [%{tag: "Ash"}],
  #       lucky_numbers: [7]
  #     })

  #   ctx.resource.update!(res, %{
  #     tags: [],
  #     lucky_numbers: []
  #   })

  #   assert %{
  #            tags: %{
  #              to: [
  #                %{destroyed: %{tag: %{from: "Ash"}, id: %{from: _ash_id}}, index: %{from: 0}}
  #              ]
  #            },
  #            lucky_numbers: %{from: [7], to: []}
  #          } = last_version_changes(ctx.api, ctx.version_resource)
  # end

  # test "making a composite array nil", ctx do
  #   res =
  #     ctx.resource.create!(%{
  #       subject: "subject",
  #       body: "body",
  #       tags: [%{tag: "Ash"}],
  #       lucky_numbers: [7]
  #     })

  #   ctx.resource.update!(res, %{
  #     tags: nil,
  #     lucky_numbers: nil
  #   })

  #   assert %{
  #            tags: %{
  #              to: [
  #                %{destroyed: %{tag: %{from: "Ash"}, id: %{from: _ash_id}}, index: %{from: 0}}
  #              ]
  #            },
  #            lucky_numbers: %{from: [7], to: nil}
  #          } = last_version_changes(ctx.api, ctx.version_resource)
  # end

  # test "update resource by creating with a union", ctx do
  #   ctx.resource.create!(%{
  #     subject: "subject",
  #     body: "body",
  #     moderator_reaction: 100
  #   })

  #   assert %{
  #            moderator_reaction: %{to: %{type: "score", value: 100}}
  #          } = last_version_changes(ctx.api, ctx.version_resource)
  # end

  # test "update resource by updating a union", ctx do
  #   res =
  #     ctx.resource.create!(%{
  #       subject: "subject",
  #       body: "body",
  #       moderator_reaction: 100
  #     })

  #   ctx.resource.update!(res, %{
  #     moderator_reaction: "like"
  #   })

  #   assert %{
  #            moderator_reaction: %{
  #              from: %{type: "score", value: 100},
  #              to: %{type: "comment", value: "like"}
  #            }
  #          } = last_version_changes(ctx.api, ctx.version_resource)
  # end

  # test "update resource by creating with an array of unions", ctx do
  #   ctx.resource.create!(%{
  #     subject: "subject",
  #     body: "body",
  #     reactions: [2, "like"]
  #   })

  #   assert %{
  #            reactions: %{
  #              to: [%{to: %{type: "score", value: 2}}, %{to: %{type: "comment", value: "like"}}]
  #            }
  #          } = last_version_changes(ctx.api, ctx.version_resource)
  # end

  # test "update resource by updating an array of unions", ctx do
  #   res =
  #     ctx.resource.create!(%{
  #       subject: "subject",
  #       body: "body",
  #       reactions: [2, "like"]
  #     })

  #   ctx.resource.update!(res, %{
  #     reactions: ["excellent", "like", 3]
  #   })

  #   assert %{
  #            reactions: %{
  #              to: [
  #               # 2 was removed from index 0
  #               %{ destroyed: %{type: "score", value: 2}, index: %{from: 0} },

  #               # excellent was added at index 0
  #               %{created: %{type: "commment", value: "excellent"}, index: %{to: 0}},

  #               # like was unchanged at index 1
  #               %{unchanged: %{type: "comment", value: "like"}, index: %{unchanged: 1}},

  #               # 3 was added at index 2
  #               %{created: %{type: "score", value: 3}, index: %{to: 2}},
  #              ]
  #            }
  #          } = last_version_changes(ctx.api, ctx.version_resource)
  # end

  # test "update resource by removing from an array of unions", ctx do
  #   res =
  #     ctx.resource.create!(%{
  #       subject: "subject",
  #       body: "body",
  #       reactions: [2, "like"]
  #     })

  #   ctx.resource.update!(res, %{
  #     reactions: [2]
  #   })

  #   assert %{
  #            reactions: %{
  #              to: [
  #                %{unchanged: %{type: %{unchanged: "score"}, value: %{unchanged: 2}}},
  #                %{from: %{type: %{from: "comment"}, value: %{from: "like"}}}
  #              ]
  #            }
  #          } = last_version_changes(ctx.api, ctx.version_resource)
  # end

  # test "create resource by creating with a union embedded resource", ctx do
  #   ctx.resource.create!(%{
  #     subject: "subject",
  #     body: "body",
  #     source: %{type: "book", name: "The Book", page: 1}
  #   })

  #   assert %{
  #            source: %{
  #              type: %{to: "book"},
  #              created: %{
  #                type: %{to: "book"},
  #                name: %{to: "The Book"},
  #                page: %{to: 1},
  #                id: %{to: _id}
  #              }
  #            }
  #          } = last_version_changes(ctx.api, ctx.version_resource)
  # end

  # test "update resource by creating with a union embedded resource", ctx do
  #   res =
  #     ctx.resource.create!(%{
  #       subject: "subject",
  #       body: "body",
  #       source: nil
  #     })

  #   ctx.resource.update!(res, %{
  #     source: %{type: "book", name: "The Book", page: 1}
  #   })

  #   assert %{
  #            source: %{
  #              from: nil,
  #              type: %{to: "book"},
  #              created: %{
  #                type: %{to: "book"},
  #                name: %{to: "The Book"},
  #                page: %{to: 1},
  #                id: %{to: _id}
  #              }
  #            }
  #          } = last_version_changes(ctx.api, ctx.version_resource)
  # end

  # test "update resource by updating a union embedded resource and leaving unchanged", ctx do
  #   res =
  #     ctx.resource.create!(%{
  #       subject: "subject",
  #       body: "body",
  #       source: %{type: "book", name: "The Book", page: 1}
  #     })

  #   book_id = res.source.value.id

  #   ctx.resource.update!(res, %{subject: "new subject"})

  #   assert %{
  #            source: %{
  #              type: %{unchanged: "book"},
  #              unchanged: %{
  #                type: %{unchanged: "book"},
  #                name: %{unchanged: "The Book"},
  #                page: %{unchanged: 1},
  #                id: %{unchanged: ^book_id}
  #              }
  #            }
  #          } = last_version_changes(ctx.api, ctx.version_resource)
  # end

  # test "update resource by updating a union embedded resource", ctx do
  #   res =
  #     ctx.resource.create!(%{
  #       subject: "subject",
  #       body: "body",
  #       source: %{type: "book", name: "The Book", page: 1}
  #     })

  #   book_id = res.source.value.id

  #   ctx.resource.update!(res, %{
  #     source: %{type: "book", name: "The Other Book", page: 12, id: book_id}
  #   })

  #   assert %{
  #            source: %{
  #              type: %{unchanged: "book"},
  #              updated: %{
  #                type: %{unchanged: "book"},
  #                name: %{to: "The Other Book", from: "The Book"},
  #                page: %{to: 12, from: 1}
  #                # FIXME: why does id change?
  #                # id: %{unchanged: ^book_id}
  #              }
  #            }
  #          } = last_version_changes(ctx.api, ctx.version_resource)
  # end

  # test "update resource by updating a union embedded resource and changing embedded type",
  #      ctx do
  #   res =
  #     ctx.resource.create!(%{
  #       subject: "subject",
  #       body: "body",
  #       source: %{type: "book", name: "The Book", page: 1}
  #     })

  #   ctx.resource.update!(res, %{
  #     source: %{type: "blog", name: "The Blog", url: "https://www.myblog.com"}
  #   })

  #   assert %{
  #            source: %{
  #              type: %{from: "book", to: "blog"},
  #              destroyed: %{
  #                type: %{from: "book"},
  #                name: %{from: "The Book"},
  #                page: %{from: 1}
  #              },
  #              created: %{
  #                type: %{to: "blog"},
  #                name: %{to: "The Blog"},
  #                url: %{to: "https://www.myblog.com"}
  #              }
  #            }
  #          } = last_version_changes(ctx.api, ctx.version_resource)
  # end

  # test "update resource by updating a union embedded resource and changing to non-embedded type",
  #      ctx do
  #   res =
  #     ctx.resource.create!(%{
  #       subject: "subject",
  #       body: "body",
  #       source: %{type: "book", name: "The Book", page: 1}
  #     })

  #   ctx.resource.update!(res, %{
  #     source: "https://www.just-a-link.com"
  #   })

  #   assert %{
  #            source: %{
  #              type: %{from: "book"},
  #              destroyed: %{
  #                type: %{from: "book"},
  #                name: %{from: "The Book"},
  #                page: %{from: 1}
  #              },
  #              to: %{type: "link", value: "https://www.just-a-link.com"}
  #            }
  #          } = last_version_changes(ctx.api, ctx.version_resource)
  # end

  # test "update resource by updating a union embedded resource and changing from non-embedded type",
  #      ctx do
  #   res =
  #     ctx.resource.create!(%{
  #       subject: "subject",
  #       body: "body",
  #       source: "https://www.just-a-link.com"
  #     })

  #   ctx.resource.update!(res, %{
  #     source: %{type: "book", name: "The Book", page: 1}
  #   })

  #   assert %{
  #            source: %{
  #              type: %{to: "book"},
  #              created: %{
  #                type: %{to: "book"},
  #                name: %{to: "The Book"},
  #                page: %{to: 1}
  #              },
  #              from: %{type: "link", value: "https://www.just-a-link.com"}
  #            }
  #          } = last_version_changes(ctx.api, ctx.version_resource)
  # end

  # test "update resource by updating a union embedded resource and changing from non-embedded type to non-embedded type", ctx do
  #   res = ctx.resource.create!(%{
  #     subject: "subject",
  #     body: "body",
  #     source: "https://www.just-a-link.com"
  #   })

  #   ctx.resource.update!(res, %{
  #     source: "https://www.just-another-link.com"
  #   })

  #   assert %{
  #     source: %{
  #       from: %{type: "link", value: "https://www.just-a-link.com"},
  #       to: %{type: "link", value: "https://www.just-another-link.com"}
  #     }
  #   } = last_version_changes(ctx.api, ctx.version_resource)
  # end

  # test "create resource with an array of union embedded resources", ctx do
  #   ctx.resource.create!(%{
  #     subject: "subject",
  #     body: "body",
  #     references: [
  #       %{type: "book", name: "The Book", page: 1},
  #       %{type: "blog", name: "The Blog", url: "https://www.myblog.com"},
  #       "https://www.just-a-link.com"
  #     ]
  #   })

  #   assert %{
  #     references: %{to: [
  #       %{created: %{ type: %{to: "book"}, name: %{to: "The Book"}, page: %{to: 1}}, index: %{to: 0}, type: %{to: "book"}},
  #       %{created: %{ type: %{to: "blog"}, name: %{to: "The Blog"}, url: "https://www.myblog.com"}, index: %{to: 1}, type: %{to: "blog"}},
  #       %{type: "link", value: "https://www.just-another-link.com", index: %{to: 3}}
  #     ]}
  #   } = last_version_changes(ctx.api, ctx.version_resource)
  # end

  # test "update resource by updating with a union resource to an embedded array" do
  # end

  # test "update resource by destroying with a union resource to an embedded array" do
  # end

  # test "update resource by reordering with a union resource to an embedded array" do
  # end
end
