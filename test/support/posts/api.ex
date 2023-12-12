defmodule AshPaperTrail.Test.Posts.Api do
  @moduledoc false
  use Ash.Api, extensions: [AshPaperTrail.Api], validate_config_inclusion?: false

  resources do
    allow {__MODULE__, :existing_mfa, [true]}
    resource AshPaperTrail.Test.Posts.Post
    resource AshPaperTrail.Test.Posts.Post.Version
    resource AshPaperTrail.Test.Posts.FullDiffPost
    resource AshPaperTrail.Test.Posts.FullDiffPost.Version
  end

  def existing_mfa(true) do
    send(self(), :existing_allow_mfa_called)
    true
  end
end
