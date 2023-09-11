defmodule AshPaperTrail.Test.Post do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshPaperTrail.Resource]


    # TODO:
    # We will probably need another test class that keeps the original functionality:
    # -    data_layer: Ash.DataLayer.Ets,
    #
    #
    #  ets do
    #    private? true
    #   end
    #


    postgres do
      table "posts"
      repo AshPaperTrail.Test.Repo
    end

  paper_trail do
    attributes_as_attributes [:subject, :body]
  end

  code_interface do
    define_for AshPaperTrail.Test.Api

    define :create, args: [:subject, :body]
    define :read
    define :update
    define :destroy
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end

  attributes do
    uuid_primary_key :id

    attribute :subject, :string do
      allow_nil? false
    end

    attribute :body, :string do
      allow_nil? false
    end
  end
end
