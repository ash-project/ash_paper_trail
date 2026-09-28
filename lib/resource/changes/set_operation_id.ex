# SPDX-FileCopyrightText: 2022 ash_paper_trail contributors <https://github.com/ash-project/ash_paper_trail/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshPaperTrail.Resource.Changes.SetOperationId do
  @moduledoc """
  Sets `context.shared.ash_paper_trail.operation_id` on the changeset if it is not already set.
  """
  use Ash.Resource.Change

  @impl true
  def temporal_safe?(_opts), do: true

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.set_context(changeset, operation_id_context(changeset.context))
  end

  @impl true
  def atomic(changeset, opts, context), do: {:ok, change(changeset, opts, context)}

  # Every changeset in a batch shares the bulk action's context, so they all belong to the
  # same operation.
  @impl true
  def batch_change([], _opts, _context), do: []

  def batch_change([first | _] = changesets, _opts, _context) do
    context = operation_id_context(first.context)
    Enum.map(changesets, &Ash.Changeset.set_context(&1, context))
  end

  @doc false
  def operation_id_context(context_or_operation_id)

  def operation_id_context(context) when is_map(context) do
    context
    |> AshPaperTrail.Resource.Info.operation_id()
    |> operation_id_context()
  end

  def operation_id_context(nil), do: operation_id_context(Ash.UUIDv7.generate())

  def operation_id_context(operation_id) do
    %{shared: %{ash_paper_trail: %{operation_id: operation_id}}}
  end
end
