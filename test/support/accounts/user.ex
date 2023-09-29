defmodule AshPaperTrail.Test.Accounts.User do
  use Ash.Resource,
    data_layer: Ash.DataLayer.Ets,
    validate_api_inclusion?: false

  ets do
    private? true
  end

  code_interface do
    define_for AshPaperTrail.Test.Accounts.Api

    define :create
    define :read
  end

  actions do
    defaults [:create, :read]
    default_accept [:name]
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string
  end
end
