# SPDX-FileCopyrightText: 2020 Zach Daniel
#
# SPDX-License-Identifier: MIT

defmodule AshPaperTrail.Test.Posts.SourceBlog do
  @moduledoc false
  use Ash.Resource,
    data_layer: :embedded,
    validate_domain_inclusion?: false

  attributes do
    uuid_primary_key :id, writable?: true

    attribute :type, :string, public?: true
    attribute :name, :string, public?: true
    attribute :url, :string, public?: true
  end
end
