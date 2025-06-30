defmodule AshPaperTrail.Test.Posts.NoDestroyVersionPost do
  @moduledoc """
  A post resource that doesn't create versions on destroy
  """

  use Ash.Resource,
    domain: AshPaperTrail.Test.Posts.Domain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshPaperTrail.Resource],
    validate_domain_inclusion?: false

  ets do
    private? true
  end

  paper_trail do
    attributes_as_attributes [:subject, :body]
    create_version_on_destroy? false
  end

  code_interface do
    define :create
    define :read
    define :update
    define :destroy
  end

  actions do
    default_accept :*
    defaults [:create, :read, :update, :destroy]
  end

  attributes do
    uuid_primary_key :id

    attribute :subject, :string do
      public? true
      allow_nil? false
    end

    attribute :body, :string do
      public? true
      allow_nil? false
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end
end