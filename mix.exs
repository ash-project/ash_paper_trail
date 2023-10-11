defmodule AshPaperTrail.MixProject do
  use Mix.Project

  def project do
    [
      app: :ash_paper_trail,
      version: "0.1.0",
      elixir: "~> 1.14",
      aliases: aliases(),
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps()
    ]
  end

  defp elixirc_paths(:test) do
    ["lib", "test/support"]
  end

  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ash, "~> 2.4"},
      {:ex_doc, "~> 0.22", only: :dev, runtime: false},
      {:ex_check, "~> 0.12.0", only: :dev},
      {:credo, ">= 0.0.0", only: :dev, runtime: false},
      {:dialyxir, ">= 0.0.0", only: :dev, runtime: false},
      {:sobelow, ">= 0.0.0", only: :dev, runtime: false},
      {:git_ops, "~> 2.5.1", only: :dev},
      {:excoveralls, "~> 0.13.0", only: [:dev, :test]}
    ]
  end

  defp aliases do
    [
      sobelow: "sobelow --skip",
      docs: [
        "spark.cheat_sheets",
        "docs",
        "spark.replace_doc_links",
        "spark.cheat_sheets_in_search"
      ],
      credo: "credo --strict",
      "spark.formatter":
        "spark.formatter --extensions AshPaperTrail.Resource,AshPaperTrail.Registry,AshPaperTrail.Api",
      "spark.cheat_sheets_in_search":
        "spark.cheat_sheets_in_search --extensions AshPaperTrail.Resource,AshPaperTrail.Registry,AshPaperTrail.Api",
      "spark.cheat_sheets":
        "spark.cheat_sheets --extensions AshPaperTrail.Resource,AshPaperTrail.Registry,AshPaperTrail.Api"
    ]
  end
end
