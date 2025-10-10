# SPDX-FileCopyrightText: 2020 Zach Daniel
#
# SPDX-License-Identifier: MIT

defmodule AshPaperTrail.Test.Accounts.NewsFeed do
  @moduledoc false
  use Ash.Resource,
    domain: AshPaperTrail.Test.Accounts.Domain,
    data_layer: Ash.DataLayer.Ets,
    validate_domain_inclusion?: false

  ets do
    private? true
  end

  code_interface do
    define :create
    define :read
  end

  actions do
    default_accept [:organization]
    defaults [:create, :read]
  end

  attributes do
    uuid_primary_key :id, writable?: true

    attribute :organization, :string, public?: true
  end
end
