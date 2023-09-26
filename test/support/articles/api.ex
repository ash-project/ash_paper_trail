defmodule AshPaperTrail.Test.Articles.Api do
  use Ash.Api, extensions: [AshPaperTrail.Api], validate_config_inclusion?: false

  resources do
    allow {__MODULE__, :existing_mfa, [true]}
    resource AshPaperTrail.Test.Articles.Article
  end

  def existing_mfa(true) do
    send(self(), :existing_allow_mfa_called)
    true
  end
end
