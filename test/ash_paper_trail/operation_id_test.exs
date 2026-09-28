# SPDX-FileCopyrightText: 2022 ash_paper_trail contributors <https://github.com/ash-project/ash_paper_trail/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshPaperTrail.OperationIdTest do
  use ExUnit.Case, async: false

  alias AshPaperTrail.Test.Posts.{OperationIdPost, TemporalOperationIdPost}

  setup do
    on_exit(fn ->
      Ash.DataLayer.Ets.stop(OperationIdPost)
      Ash.DataLayer.Ets.stop(OperationIdPost.Version)
      Ash.DataLayer.Ets.stop(TemporalOperationIdPost)
    end)
  end

  defp versions do
    Ash.read!(OperationIdPost.Version, authorize?: false)
  end

  defp operation_ids do
    versions() |> Enum.map(& &1.operation_id) |> Enum.uniq()
  end

  test "the operation id attribute is added to the version resource" do
    assert %{type: Ash.Type.UUID, public?: true} =
             Ash.Resource.Info.attribute(OperationIdPost.Version, :operation_id)
  end

  test "each top level action call gets its own operation id" do
    post = OperationIdPost.create!(%{subject: "a"})
    OperationIdPost.update!(post, %{subject: "b"})

    assert [id1, id2] = operation_ids()
    assert is_binary(id1) and is_binary(id2)
    assert id1 != id2
  end

  test "a provided operation id is used" do
    id = Ash.UUIDv7.generate()

    post =
      OperationIdPost.create!(%{subject: "a"},
        context: %{shared: %{ash_paper_trail: %{operation_id: id}}}
      )

    OperationIdPost.update!(post, %{subject: "b"},
      context: %{shared: %{ash_paper_trail: %{operation_id: id}}}
    )

    assert operation_ids() == [id]
  end

  test "the operation id is available in the context" do
    changeset = Ash.Changeset.for_create(OperationIdPost, :create, %{subject: "a"})

    assert %{
             ash_paper_trail: %{operation_id: id},
             shared: %{ash_paper_trail: %{operation_id: id}}
           } =
             changeset.context

    assert is_binary(id)
  end

  test "the operation id is set before an action's own preparations and changes" do
    OperationIdPost.read_requiring_operation_id!()
    OperationIdPost.create_requiring_operation_id!(%{subject: "a"})
  end

  test "writes in a create's hooks share its operation id" do
    OperationIdPost.create_with_child!(%{subject: "parent"})

    assert length(versions()) == 2
    assert [_] = operation_ids()
  end

  test "writes in a generic action share its operation id" do
    OperationIdPost.create_two!("post")

    assert length(versions()) == 2
    assert [_] = operation_ids()
  end

  test "writes in a read's hooks share its operation id" do
    OperationIdPost.create!(%{subject: "a"})
    OperationIdPost.create!(%{subject: "b"})
    [create_id1, create_id2] = operation_ids()

    OperationIdPost.read_and_update!()

    assert [read_id] = operation_ids() -- [create_id1, create_id2]
    assert Enum.count(versions(), &(&1.operation_id == read_id)) == 2
  end

  test "records in a bulk create share an operation id" do
    Ash.bulk_create!(
      [%{subject: "a"}, %{subject: "b"}, %{subject: "c"}],
      OperationIdPost,
      :create
    )

    assert length(versions()) == 3
    assert [_] = operation_ids()
  end

  test "records in an atomic bulk update share an operation id" do
    OperationIdPost.create!(%{subject: "a"})
    OperationIdPost.create!(%{subject: "b"})
    create_ids = operation_ids()

    OperationIdPost
    |> Ash.Query.new()
    |> Ash.bulk_update!(:update, %{body: "bulk"}, strategy: :atomic)

    assert [_] = operation_ids() -- create_ids
  end

  describe "temporal_inline mode" do
    test "each version row stores the operation id of the write that produced it" do
      id = Ash.UUIDv7.generate()

      post = TemporalOperationIdPost.create!(%{subject: "a"})

      TemporalOperationIdPost.update!(post, %{subject: "b"},
        context: %{shared: %{ash_paper_trail: %{operation_id: id}}}
      )

      assert [first, second] =
               TemporalOperationIdPost.Version
               |> Ash.read!()
               |> Enum.sort_by(& &1.valid_at.lower, DateTime)

      assert is_binary(first.operation_id)
      assert first.operation_id != id
      assert second.operation_id == id
    end
  end
end
