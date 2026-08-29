# SPDX-FileCopyrightText: 2022 ash_paper_trail contributors <https://github.com/ash-project/ash_paper_trail/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshPaperTrail.RedactNestedTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias AshPaperTrail.ChangeBuilders.FullDiff.Helpers

  defmodule Credential do
    @moduledoc false
    use Ash.Resource, data_layer: :embedded, validate_domain_inclusion?: false

    attributes do
      uuid_primary_key :id, writable?: true
      attribute :username, :string, public?: true
      attribute :token, :string, public?: true, sensitive?: true
    end
  end

  defmodule Wrapper do
    @moduledoc false
    use Ash.Resource, data_layer: :embedded, validate_domain_inclusion?: false

    attributes do
      uuid_primary_key :id, writable?: true
      attribute :name, :string, public?: true
      attribute :credential, Credential, public?: true
    end
  end

  defp dump(type, value, constraints \\ []) do
    {:ok, dumped} = Ash.Type.dump_to_embedded(type, value, constraints)
    dumped
  end

  describe "redact_dumped_value/4 on embedded resources" do
    test ":display leaves nested sensitive fields untouched" do
      dumped = dump(Credential, %Credential{username: "bob", token: "s3cret"})
      assert Helpers.redact_dumped_value(dumped, Credential, [], :display) == dumped
      assert dumped[:token] == "s3cret" or dumped["token"] == "s3cret"
    end

    test ":redact replaces the nested sensitive field with REDACTED" do
      dumped = dump(Credential, %Credential{username: "bob", token: "s3cret"})
      redacted = Helpers.redact_dumped_value(dumped, Credential, [], :redact)

      assert token(redacted) == "REDACTED"
      assert username(redacted) == "bob"
    end

    test ":ignore drops the nested sensitive field entirely" do
      dumped = dump(Credential, %Credential{username: "bob", token: "s3cret"})
      redacted = Helpers.redact_dumped_value(dumped, Credential, [], :ignore)

      refute Map.has_key?(redacted, :token)
      refute Map.has_key?(redacted, "token")
      assert username(redacted) == "bob"
    end

    test "recurses into a nested embed" do
      dumped =
        dump(Wrapper, %Wrapper{
          name: "outer",
          credential: %Credential{username: "bob", token: "s3cret"}
        })

      redacted = Helpers.redact_dumped_value(dumped, Wrapper, [], :redact)

      credential = redacted[:credential] || redacted["credential"]
      assert token(credential) == "REDACTED"
      assert username(credential) == "bob"
    end

    test "redacts within an array of embeds" do
      values = [
        %Credential{username: "a", token: "t1"},
        %Credential{username: "b", token: "t2"}
      ]

      dumped = Enum.map(values, &dump(Credential, &1))

      redacted =
        Helpers.redact_dumped_value(dumped, {:array, Credential}, [items: []], :redact)

      assert Enum.map(redacted, &token/1) == ["REDACTED", "REDACTED"]
      assert Enum.map(redacted, &username/1) == ["a", "b"]
    end
  end

  defp token(map), do: map[:token] || map["token"]
  defp username(map), do: map[:username] || map["username"]
end
