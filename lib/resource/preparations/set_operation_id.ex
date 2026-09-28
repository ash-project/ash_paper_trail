# SPDX-FileCopyrightText: 2022 ash_paper_trail contributors <https://github.com/ash-project/ash_paper_trail/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshPaperTrail.Resource.Preparations.SetOperationId do
  @moduledoc """
  Sets `context.shared.ash_paper_trail.operation_id` on the query or action input if it is not
  already set.
  """
  use Ash.Resource.Preparation

  import AshPaperTrail.Resource.Changes.SetOperationId, only: [operation_id_context: 1]

  @impl true
  def supports(_opts), do: [Ash.Query, Ash.ActionInput]

  @impl true
  def temporal_safe?(_opts), do: true

  @impl true
  def prepare(%Ash.Query{} = query, _opts, _context) do
    Ash.Query.set_context(query, operation_id_context(query.context))
  end

  def prepare(%Ash.ActionInput{} = input, _opts, _context) do
    Ash.ActionInput.set_context(input, operation_id_context(input.context))
  end
end
