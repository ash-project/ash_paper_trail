# SPDX-FileCopyrightText: 2022 ash_paper_trail contributors <https://github.com/ash-project/ash_paper_trail/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshPaperTrail.Test.Articles.Article do
  @moduledoc false
  use Ash.Resource,
    domain: AshPaperTrail.Test.Articles.Domain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshPaperTrail.Resource],
    validate_domain_inclusion?: false

  ets do
    private? true
  end

  paper_trail do
    attributes_as_attributes [:subject, :body]
    ignore_actions [:destroy]
    change_tracking_mode :snapshot
    public_timestamps?(true)
  end

  code_interface do
    define :create, args: [:subject, :body]
    define :read
    define :update
    define :destroy
  end

  actions do
    default_accept [:*, :body]
    defaults [:create, :read, :update, :destroy]
  end

  attributes do
    uuid_primary_key :id, writable?: true

    attribute :subject, :string do
      public? true
      allow_nil? false
    end

    attribute :body, :string do
      public? false
      allow_nil? false
    end
  end
end
