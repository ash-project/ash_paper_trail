# SPDX-FileCopyrightText: 2022 ash_paper_trail contributors <https://github.com/ash-project/ash_paper_trail/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshPaperTrail.Test.Posts.TemporalOperationIdPost do
  @moduledoc """
  A temporal resource versioned in `:temporal_inline` mode that stores an operation id.
  """

  use Ash.Resource,
    domain: AshPaperTrail.Test.Posts.Domain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshPaperTrail.Resource],
    validate_domain_inclusion?: false

  ets do
    private? true
  end

  temporal do
    strategy :context
    attribute :valid_at
  end

  paper_trail do
    mode(:temporal_inline)
    version_resource? true
    operation_id_field(:operation_id)
    public_version_attributes([:operation_id])
  end

  code_interface do
    define :create
    define :update
  end

  actions do
    default_accept :*
    defaults [:read, create: :*, update: :*]
  end

  attributes do
    uuid_primary_key :id

    attribute :subject, :string do
      public? true
      allow_nil? false
    end
  end
end
