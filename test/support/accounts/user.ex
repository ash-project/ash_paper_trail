# SPDX-FileCopyrightText: 2020 Zach Daniel
#
# SPDX-License-Identifier: MIT

defmodule AshPaperTrail.Test.Accounts.User do
  @moduledoc false
  use Ash.Resource,
    domain: AshPaperTrail.Test.Accounts.Domain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshPaperTrail.Resource],
    validate_domain_inclusion?: false

  ets do
    private? true
  end

  paper_trail do
    primary_key_type :uuid_v7
  end

  code_interface do
    define :create
    define :read
    define :update
  end

  actions do
    default_accept [:name]
    defaults [:create, :read, :update]
  end

  attributes do
    uuid_primary_key :id, writable?: true

    attribute :name, :string, public?: true
  end
end
