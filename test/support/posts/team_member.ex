# SPDX-FileCopyrightText: 2022 ash_paper_trail contributors <https://github.com/ash-project/ash_paper_trail/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshPaperTrail.Test.Posts.TeamMember do
  @moduledoc false

  @composite_key_count 10
  @composite_keys for(i <- 1..@composite_key_count, do: String.to_atom("key_#{i}"))

  use Ash.Resource,
    domain: AshPaperTrail.Test.Posts.Domain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshPaperTrail.Resource],
    validate_domain_inclusion?: false

  ets do
    private? true
  end

  paper_trail do
    primary_key_type :uuid
    relationship_opts public?: true
  end

  code_interface do
    define :create
    define :read
    define :destroy
  end

  actions do
    default_accept :*
    defaults [:create, :read, :destroy]
  end

  attributes do
    for key <- @composite_keys do
      attribute key, :uuid do
        primary_key? true
        allow_nil? false
        public? true
      end
    end
  end

  def composite_keys, do: @composite_keys
end
