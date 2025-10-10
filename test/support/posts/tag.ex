# SPDX-FileCopyrightText: 2020 Zach Daniel
#
# SPDX-License-Identifier: MIT

defmodule AshPaperTrail.Test.Posts.Tag do
  @moduledoc false
  use Ash.Resource,
    data_layer: :embedded,
    validate_domain_inclusion?: false

  attributes do
    uuid_primary_key :id, writable?: true

    attribute :tag, :string, public?: true
  end
end
