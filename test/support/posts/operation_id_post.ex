# SPDX-FileCopyrightText: 2022 ash_paper_trail contributors <https://github.com/ash-project/ash_paper_trail/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshPaperTrail.Test.Posts.OperationIdPost do
  @moduledoc """
  A resource versioned with a version resource that stores an operation id.
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
    primary_key_type :uuid_v7
    change_tracking_mode :changes_only
    operation_id_field(:operation_id)
  end

  code_interface do
    define :create
    define :read
    define :update
    define :destroy
    define :create_with_child
    define :create_two, args: [:subject]
    define :read_and_update
    define :read_requiring_operation_id
    define :create_requiring_operation_id
  end

  actions do
    default_accept :*
    defaults [:read, :destroy, create: :*, update: :*]

    create :create_with_child do
      change fn changeset, context ->
        Ash.Changeset.after_action(changeset, fn changeset, result ->
          __MODULE__.create!(%{subject: "child of #{result.subject}"}, scope: context)
          {:ok, result}
        end)
      end
    end

    action :create_two, {:array, :struct} do
      constraints items: [instance_of: __MODULE__]
      argument :subject, :string, allow_nil?: false

      run fn input, context ->
        {:ok,
         [
           __MODULE__.create!(%{subject: input.arguments.subject <> " 1"}, scope: context),
           __MODULE__.create!(%{subject: input.arguments.subject <> " 2"}, scope: context)
         ]}
      end
    end

    read :read_requiring_operation_id do
      prepare fn query, _context ->
        if query.context[:ash_paper_trail][:operation_id] do
          query
        else
          raise "operation id not set before action preparations"
        end
      end
    end

    create :create_requiring_operation_id do
      change fn changeset, _context ->
        if changeset.context[:ash_paper_trail][:operation_id] do
          changeset
        else
          raise "operation id not set before action changes"
        end
      end
    end

    read :read_and_update do
      prepare fn query, context ->
        Ash.Query.after_action(query, fn _query, results ->
          {:ok, Enum.map(results, &__MODULE__.update!(&1, %{body: "touched"}, scope: context))}
        end)
      end
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :subject, :string do
      public? true
      allow_nil? false
    end

    attribute :body, :string do
      public? true
    end
  end
end
