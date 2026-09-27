# SPDX-FileCopyrightText: 2022 ash_paper_trail contributors <https://github.com/ash-project/ash_paper_trail/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshPaperTrail.Test.Posts.PreviousValuesPost do
  @moduledoc """
  A resource versioned with a version resource and `:previous_values` tracking.
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
    change_tracking_mode :previous_values
    ignore_attributes [:inserted_at, :updated_at]
  end

  code_interface do
    define :create
    define :read
    define :update
  end

  actions do
    default_accept :*
    defaults [:read, create: :*]

    update :update do
      primary? true
      require_atomic? false
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

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end
end
