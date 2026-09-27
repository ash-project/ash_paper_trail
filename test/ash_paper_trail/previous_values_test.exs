# SPDX-FileCopyrightText: 2022 ash_paper_trail contributors <https://github.com/ash-project/ash_paper_trail/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshPaperTrail.PreviousValuesTest do
  use ExUnit.Case, async: false

  alias AshPaperTrail.Test.Posts

  require Ash.Query

  setup do
    on_exit(fn ->
      Ash.DataLayer.Ets.stop(Posts.PreviousValuesPost)
      Ash.DataLayer.Ets.stop(Posts.PreviousValuesPost.Version)
    end)
  end

  test "versions store the previous values of the attributes that changed" do
    post = Posts.PreviousValuesPost.create!(%{subject: "subject", body: "body"})
    Posts.PreviousValuesPost.update!(post, %{body: "new body"})

    assert [%{changes: %{}}, %{changes: %{body: "body"}}] =
             Posts.PreviousValuesPost.Version
             |> Ash.read!()
             |> Enum.sort_by(& &1.version_inserted_at)
  end

  test "cannot be tracked atomically" do
    post = Posts.PreviousValuesPost.create!(%{subject: "subject", body: "body"})

    assert %Ash.BulkResult{status: :error, errors: [_ | _]} =
             Posts.PreviousValuesPost
             |> Ash.Query.filter(id == ^post.id)
             |> Ash.bulk_update(:update, %{body: "new body"},
               strategy: :atomic,
               return_errors?: true
             )
  end
end
