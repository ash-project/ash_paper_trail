defmodule AshPaperTrail.EmptyUse do
  @moduledoc false
  defmacro __using__(_) do
    quote do
    end
  end
end
