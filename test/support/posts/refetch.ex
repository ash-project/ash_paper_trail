# SPDX-FileCopyrightText: 2022 ash_paper_trail contributors <https://github.com/ash-project/ash_paper_trail/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshPaperTrail.Test.Posts.Refetch do
  @moduledoc """
  Re-reads the record being updated in a `before_action` hook, as `get_and_lock_for_update`
  does, without the lock, which ETS doesn't support.
  """
  use Ash.Resource.Change

  @impl true
  def temporal_safe?(_opts), do: true

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.before_action(changeset, fn changeset ->
      %{changeset | data: Ash.get!(changeset.resource, changeset.data.id, authorize?: false)}
    end)
  end
end
