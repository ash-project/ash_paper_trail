# SPDX-FileCopyrightText: 2022 ash_paper_trail contributors <https://github.com/ash-project/ash_paper_trail/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshPaperTrail.RedactPersistenceTest do
  @moduledoc """
  Integration tests for GitHub issue #30: scrub sensitive values when persisting
  `version_action_inputs` and `changes`.

  See: https://github.com/ash-project/ash_paper_trail/issues/30

  These tests focus on gaps called out for #30—nested embeds/unions, multiple
  change-tracking modes, temporal inline, and opt-in `sensitive_attributes` policy—
  rather than duplicating coverage in `ash_paper_trail_test.exs` or
  `redact_nested_integration_test.exs`.
  """

  use ExUnit.Case, async: false

  require Ash.Query

  alias __MODULE__

  @secret_token "s3cret-token-do-not-persist"
  @top_secret "top-level-secret-value"

  # --- Shared embedded / union types ---------------------------------------------------

  defmodule Credential do
    @moduledoc false
    use Ash.Resource, data_layer: :embedded, validate_domain_inclusion?: false

    attributes do
      uuid_primary_key :id, writable?: true
      attribute :username, :string, public?: true
      attribute :token, :string, public?: true, sensitive?: true
    end
  end

  defmodule SensitiveIdentity do
    @moduledoc false
    use Ash.Type.NewType,
      subtype_of: :union,
      constraints: [
        storage: :type_and_value,
        types: [
          credential: [
            tag: :type,
            tag_value: :credential,
            type: RedactPersistenceTest.Credential
          ],
          note: [
            type: :string
          ]
        ]
      ]
  end

  defmodule Domain do
    @moduledoc false
    use Ash.Domain, validate_config_inclusion?: false

    resources do
      resource RedactPersistenceTest.InputsPost
      resource RedactPersistenceTest.InputsPost.Version
      resource RedactPersistenceTest.InputsDisplayPost
      resource RedactPersistenceTest.InputsDisplayPost.Version
      resource RedactPersistenceTest.ChangesOnlyPost
      resource RedactPersistenceTest.ChangesOnlyPost.Version
      resource RedactPersistenceTest.SnapshotPost
      resource RedactPersistenceTest.SnapshotPost.Version
      resource RedactPersistenceTest.PreviousValuesPost
      resource RedactPersistenceTest.PreviousValuesPost.Version
      resource RedactPersistenceTest.UnionPost
      resource RedactPersistenceTest.UnionPost.Version
      resource RedactPersistenceTest.TemporalInlinePost
      resource RedactPersistenceTest.TemporalInlinePost.Version
    end
  end

  defmodule InputsPost do
    @moduledoc false
    use Ash.Resource,
      domain: RedactPersistenceTest.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshPaperTrail.Resource],
      validate_domain_inclusion?: false

    ets do
      private? true
    end

    paper_trail do
      change_tracking_mode :changes_only
      store_action_inputs? true
      sensitive_attributes :redact
    end

    code_interface do
      define :create
      define :read
      define :update
      define :destroy
    end

    attributes do
      uuid_primary_key :id
      attribute :subject, :string, public?: true, allow_nil?: false
      attribute :secret, :string, public?: true, sensitive?: true
      attribute :credential, RedactPersistenceTest.Credential, public?: true, allow_nil?: true
      attribute :identity, RedactPersistenceTest.SensitiveIdentity, public?: true, allow_nil?: true
    end

    actions do
      defaults [:read, :destroy]

      create :create do
        accept [:subject, :secret, :credential, :identity]
        argument :api_key, :string, sensitive?: true, allow_nil?: true
      end

      update :update do
        accept [:subject, :secret, :credential, :identity]
        argument :api_key, :string, sensitive?: true, allow_nil?: true
      end
    end
  end

  defmodule InputsDisplayPost do
    @moduledoc false
    use Ash.Resource,
      domain: RedactPersistenceTest.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshPaperTrail.Resource],
      validate_domain_inclusion?: false

    ets do
      private? true
    end

    paper_trail do
      change_tracking_mode :changes_only
      store_action_inputs? true
      sensitive_attributes :display
    end

    code_interface do
      define :create
      define :read
      define :update
      define :destroy
    end

    attributes do
      uuid_primary_key :id
      attribute :subject, :string, public?: true, allow_nil?: false
      attribute :credential, RedactPersistenceTest.Credential, public?: true, allow_nil?: true
    end

    actions do
      default_accept :*
      defaults [:create, :read, :update, :destroy]
    end
  end

  defmodule ChangesOnlyPost do
    @moduledoc false
    use Ash.Resource,
      domain: RedactPersistenceTest.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshPaperTrail.Resource],
      validate_domain_inclusion?: false

    ets do
      private? true
    end

    paper_trail do
      change_tracking_mode :changes_only
      sensitive_attributes :redact
    end

    code_interface do
      define :create
      define :read
      define :update
      define :destroy
    end

    attributes do
      uuid_primary_key :id
      attribute :subject, :string, public?: true, allow_nil?: false
      attribute :credential, RedactPersistenceTest.Credential, public?: true, allow_nil?: true
    end

    actions do
      default_accept :*
      defaults [:create, :read, :update, :destroy]
    end
  end

  defmodule SnapshotPost do
    @moduledoc false
    use Ash.Resource,
      domain: RedactPersistenceTest.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshPaperTrail.Resource],
      validate_domain_inclusion?: false

    ets do
      private? true
    end

    paper_trail do
      change_tracking_mode :snapshot
      sensitive_attributes :redact
    end

    code_interface do
      define :create
      define :read
      define :update
      define :destroy
    end

    attributes do
      uuid_primary_key :id
      attribute :subject, :string, public?: true, allow_nil?: false
      attribute :credential, RedactPersistenceTest.Credential, public?: true, allow_nil?: true
    end

    actions do
      default_accept :*
      defaults [:create, :read, :update, :destroy]
    end
  end

  defmodule PreviousValuesPost do
    @moduledoc false
    use Ash.Resource,
      domain: RedactPersistenceTest.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshPaperTrail.Resource],
      validate_domain_inclusion?: false

    ets do
      private? true
    end

    paper_trail do
      change_tracking_mode :previous_values
      sensitive_attributes :redact
    end

    code_interface do
      define :create
      define :read
      define :update
      define :destroy
    end

    attributes do
      uuid_primary_key :id
      attribute :subject, :string, public?: true, allow_nil?: false
      attribute :secret, :string, public?: true, sensitive?: true
      attribute :credential, RedactPersistenceTest.Credential, public?: true, allow_nil?: true
    end

    actions do
      default_accept :*
      defaults [:create, :read, :update, :destroy]
    end
  end

  defmodule UnionPost do
    @moduledoc false
    use Ash.Resource,
      domain: RedactPersistenceTest.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshPaperTrail.Resource],
      validate_domain_inclusion?: false

    ets do
      private? true
    end

    paper_trail do
      change_tracking_mode :changes_only
      store_action_inputs? true
      sensitive_attributes :redact
    end

    code_interface do
      define :create
      define :read
      define :update
      define :destroy
    end

    attributes do
      uuid_primary_key :id
      attribute :subject, :string, public?: true, allow_nil?: false
      attribute :identity, RedactPersistenceTest.SensitiveIdentity, public?: true, allow_nil?: true
    end

    actions do
      default_accept :*
      defaults [:create, :read, :update, :destroy]
    end
  end

  defmodule TemporalInlinePost do
    @moduledoc false
    use Ash.Resource,
      domain: RedactPersistenceTest.Domain,
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
      mode :temporal_inline
      version_resource? true
      change_tracking_mode :changes_only
      store_action_inputs? true
      sensitive_attributes :redact
    end

    code_interface do
      define :create
      define :read
      define :update
      define :destroy
    end

    attributes do
      uuid_primary_key :id
      attribute :subject, :string, public?: true, allow_nil?: false
      attribute :secret, :string, public?: true, sensitive?: true
      attribute :credential, RedactPersistenceTest.Credential, public?: true, allow_nil?: true
    end

    actions do
      default_accept :*
      defaults [:read, :destroy, create: :*, update: :*]

      update :increment_subject do
        accept []
        change atomic_update(:subject, expr(subject <> "-x"))
      end
    end
  end

  setup do
    on_exit(fn ->
      for resource <- [
            InputsPost,
            InputsPost.Version,
            InputsDisplayPost,
            InputsDisplayPost.Version,
            ChangesOnlyPost,
            ChangesOnlyPost.Version,
            SnapshotPost,
            SnapshotPost.Version,
            PreviousValuesPost,
            PreviousValuesPost.Version,
            UnionPost,
            UnionPost.Version,
            TemporalInlinePost,
            TemporalInlinePost.Version
          ] do
        Ash.DataLayer.Ets.stop(resource)
      end
    end)

    :ok
  end

  describe "version_action_inputs (#30 :inputs)" do
    # Purpose: Top-level attributes marked sensitive? must never be stored in plaintext
    # when action inputs are persisted (regression for scalar scrubbing on create).
    test "redacts top-level sensitive attributes in version_action_inputs on create" do
      InputsPost.create!(%{
        subject: "hello",
        secret: @top_secret,
        credential: %{username: "bob", token: @secret_token}
      })

      [version] = Ash.read!(InputsPost.Version)

      assert version.version_action_inputs[:secret] == "REDACTED"
      refute_plaintext_leak(version.version_action_inputs, @top_secret)
    end

    # Purpose: Sensitive action arguments must be scrubbed the same way as sensitive attributes.
    test "redacts sensitive action arguments in version_action_inputs" do
      InputsPost.create!(%{
        subject: "hello",
        api_key: "api-key-leak"
      })

      [version] = Ash.read!(InputsPost.Version)

      assert version.version_action_inputs[:api_key] == "REDACTED"
      refute_plaintext_leak(version.version_action_inputs, "api-key-leak")
    end

    # Purpose: Issue #30 requires traversing embeds—nested sensitive? fields must not appear
    # in stored inputs when the resource opts into redaction via sensitive_attributes :redact.
    test "redacts nested sensitive fields inside embeds in version_action_inputs" do
      InputsPost.create!(%{
        subject: "hello",
        credential: %{username: "bob", token: @secret_token}
      })

      [version] = Ash.read!(InputsPost.Version)
      inputs = version.version_action_inputs

      assert inputs[:credential][:username] == "bob" or inputs["credential"]["username"] == "bob"
      assert nested_field(inputs, [:credential, :token]) == "REDACTED"
      refute_plaintext_leak(inputs, @secret_token)
    end

    # Purpose: Union subtypes that contain embeds must be traversed so nested secrets are scrubbed
    # in stored inputs (including correct union serialization in action_inputs/2).
    test "redacts nested sensitive fields inside union embed subtypes in version_action_inputs" do
      InputsPost.create!(%{
        subject: "hello",
        identity: %{type: "credential", username: "bob", token: @secret_token}
      })

      [version] = Ash.read!(InputsPost.Version)
      inputs = version.version_action_inputs

      refute inputs[:identity] == %{},
             "expected union action inputs to be stored; empty map suggests a serialization/scrub gap"

      refute_plaintext_leak(inputs, @secret_token)

      assert nested_field(inputs, [:identity, :token]) == "REDACTED" ||
               inspect(inputs, limit: :infinity) =~ "REDACTED"
    end

    # Purpose: Maintainer guidance on #30 is opt-in redaction—when sensitive_attributes is
    # :display, nested sensitive fields may still be versioned in inputs until policy is tightened.
    test "with sensitive_attributes :display, nested sensitive embed fields may appear in version_action_inputs" do
      InputsDisplayPost.create!(%{
        subject: "hello",
        credential: %{username: "bob", token: @secret_token}
      })

      [version] = Ash.read!(InputsDisplayPost.Version)
      inputs = version.version_action_inputs

      assert nested_field(inputs, [:credential, :token]) == @secret_token
    end
  end

  describe "changes map (#30 :changes) on version resources" do
    # Purpose: :changes_only must scrub nested secrets, not only top-level sensitive attributes.
    test "changes_only redacts nested sensitive embed fields when sensitive_attributes is :redact" do
      post =
        ChangesOnlyPost.create!(%{
          subject: "hello",
          credential: %{username: "bob", token: @secret_token}
        })

      ChangesOnlyPost.update!(post, %{
        credential: %{username: "bob", token: "rotated-#{@secret_token}"}
      })

      [create_version, update_version] =
        Ash.read!(ChangesOnlyPost.Version) |> Enum.sort_by(& &1.id)

      refute_plaintext_leak(create_version.changes, @secret_token)
      refute_plaintext_leak(update_version.changes, "rotated-#{@secret_token}")
      assert inspect(update_version.changes, limit: :infinity) =~ "REDACTED"
    end

    # Purpose: Snapshot mode dumps full attribute values; nested traversal must still apply.
    test "snapshot redacts nested sensitive embed fields in changes" do
      SnapshotPost.create!(%{
        subject: "hello",
        credential: %{username: "bob", token: @secret_token}
      })

      [version] = Ash.read!(SnapshotPost.Version)

      refute_plaintext_leak(version.changes, @secret_token)
      assert inspect(version.changes, limit: :infinity) =~ "REDACTED"
    end

    # Purpose: Previous-values mode stores prior scalar attribute values; sensitive fields must scrub.
    test "previous_values redacts sensitive scalar fields in changes" do
      post =
        PreviousValuesPost.create!(%{
          subject: "hello",
          secret: @top_secret
        })

      PreviousValuesPost.update!(post, %{secret: "rotated-#{@top_secret}"})

      [_create, update] =
        Ash.read!(PreviousValuesPost.Version) |> Enum.sort_by(& &1.version_inserted_at)

      assert update.changes[:secret] == "REDACTED"
      refute_plaintext_leak(update.changes, @top_secret)
    end

    # Purpose: Union attributes must scrub nested sensitive fields inside the active subtype.
    test "changes_only redacts nested sensitive fields inside union embed subtypes" do
      post =
        UnionPost.create!(%{
          subject: "hello",
          identity: %{type: "credential", username: "bob", token: @secret_token}
        })

      cred_id = post.identity.value.id

      UnionPost.update!(post, %{
        identity: %{
          type: "credential",
          id: cred_id,
          username: "bob",
          token: "union-#{@secret_token}"
        }
      })

      [_create, update] = Ash.read!(UnionPost.Version) |> Enum.sort_by(& &1.id)

      refute_plaintext_leak(update.changes, "union-#{@secret_token}")
      assert inspect(update.changes, limit: :infinity) =~ "REDACTED"
    end

    # Purpose: Opt-in :display means plaintext nested secrets in changes are allowed (document regression).
    test "with sensitive_attributes :display, nested sensitive values may appear in changes" do
      InputsDisplayPost.create!(%{
        subject: "hello",
        credential: %{username: "bob", token: @secret_token}
      })

      [create_version] = Ash.read!(InputsDisplayPost.Version)

      assert inspect(create_version.changes, limit: :infinity) =~ @secret_token
    end
  end

  describe "temporal inline persistence (#30 both paths)" do
    @t1 ~U[2020-01-01 00:00:00Z]
    @t2 ~U[2020-01-02 00:00:00Z]

    # Purpose: Temporal inline must scrub nested secrets in changes, not only separate version rows.
    test "inline changes redact nested sensitive embed fields when sensitive_attributes is :redact" do
      post =
        TemporalInlinePost.create!(
          %{subject: "hello", credential: %{username: "bob", token: @secret_token}},
          as_of: @t1
        )

      TemporalInlinePost.update!(
        post,
        %{credential: %{username: "bob", token: "inline-#{@secret_token}"}},
        as_of: @t2
      )

      current =
        TemporalInlinePost
        |> Ash.Query.filter(id == ^post.id)
        |> Ash.read!(as_of: @t2)
        |> List.first()

      refute_plaintext_leak(current.changes, "inline-#{@secret_token}")
      assert inspect(current.changes, limit: :infinity) =~ "REDACTED"
    end

    # Purpose: Stored action inputs on inline rows must receive the same scrubbing as version resources.
    test "inline version_action_inputs redact nested sensitive embed fields" do
      TemporalInlinePost.create!(
        %{
          subject: "hello",
          credential: %{username: "bob", token: @secret_token}
        },
        as_of: @t1
      )

      row =
        TemporalInlinePost
        |> Ash.Query.filter(subject == "hello")
        |> Ash.read!(as_of: @t1)
        |> List.first()

      refute_plaintext_leak(row.version_action_inputs, @secret_token)
      assert nested_field(row.version_action_inputs, [:credential, :token]) == "REDACTED"
    end

    # Purpose: Atomic inline updates build changes from atomics; top-level sensitive attrs must still scrub.
    test "inline atomic updates redact top-level sensitive attributes in changes" do
      post =
        TemporalInlinePost.create!(
          %{subject: "hello", secret: @top_secret},
          as_of: @t1
        )

      TemporalInlinePost.update!(post, %{secret: "atomic-#{@top_secret}"}, as_of: @t2)

      current =
        TemporalInlinePost
        |> Ash.Query.filter(id == ^post.id)
        |> Ash.read!(as_of: @t2)
        |> List.first()

      assert current.changes[:secret] == "REDACTED"
      refute_plaintext_leak(current.changes, "atomic-#{@top_secret}")
    end
  end

  defp refute_plaintext_leak(data, secret) when is_binary(secret) do
    refute inspect(data, limit: :infinity) =~ secret,
           "expected #{inspect(secret)} to be scrubbed from persisted audit data"
  end

  defp nested_field(map, [key | rest]) when is_map(map) do
    value = Map.get(map, key) || Map.get(map, to_string(key))
    nested_field(value, rest)
  end

  defp nested_field(map, []) when is_map(map), do: map
  defp nested_field(value, []), do: value
end
