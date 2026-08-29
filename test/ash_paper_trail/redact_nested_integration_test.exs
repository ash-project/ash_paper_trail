# SPDX-FileCopyrightText: 2022 ash_paper_trail contributors <https://github.com/ash-project/ash_paper_trail/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshPaperTrail.RedactNestedIntegrationTest do
  @moduledoc false
  use ExUnit.Case, async: false

  defmodule Credential do
    @moduledoc false
    use Ash.Resource, data_layer: :embedded, validate_domain_inclusion?: false

    attributes do
      uuid_primary_key :id, writable?: true
      attribute :username, :string, public?: true
      attribute :token, :string, public?: true, sensitive?: true
    end
  end

  defmodule SecretPost do
    @moduledoc false
    use Ash.Resource,
      domain: AshPaperTrail.RedactNestedIntegrationTest.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshPaperTrail.Resource],
      validate_domain_inclusion?: false

    ets do
      private? true
    end

    paper_trail do
      change_tracking_mode :full_diff
      sensitive_attributes :redact
    end

    attributes do
      uuid_primary_key :id
      attribute :credential, Credential, public?: true, allow_nil?: true
    end

    actions do
      default_accept :*
      defaults [:create, :read, :update, :destroy]
    end
  end

  defmodule Domain do
    @moduledoc false
    use Ash.Domain, validate_config_inclusion?: false

    resources do
      resource AshPaperTrail.RedactNestedIntegrationTest.SecretPost
      resource AshPaperTrail.RedactNestedIntegrationTest.SecretPost.Version
    end
  end

  test "a sensitive field nested in an embed is redacted in the version changes" do
    SecretPost
    |> Ash.Changeset.for_create(:create, %{credential: %{username: "bob", token: "s3cret"}})
    |> Ash.create!()

    [version] = Ash.read!(SecretPost.Version)

    dumped = inspect(version.changes, limit: :infinity)

    refute dumped =~ "s3cret", "the plaintext secret leaked into the version changes"
    assert dumped =~ "REDACTED"
  end
end
