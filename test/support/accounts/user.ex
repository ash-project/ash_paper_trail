defmodule AshPaperTrail.Test.Accounts.User do
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
    default_accept [:name]
    defaults [:create, :read]
  end

  attributes do
    uuid_primary_key :id, writable?: true

    attribute :name, :string, public?: true
  end
end
