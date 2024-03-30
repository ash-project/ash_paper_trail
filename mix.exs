defmodule AshPaperTrail.MixProject do
  use Mix.Project

  @version "0.1.1"

  @description """
  Creates and manage a version tracking resource for a given resource.
  """

  def project do
    [
      app: :ash_paper_trail,
      version: @version,
      elixir: "~> 1.14",
      aliases: aliases(),
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      package: package(),
      deps: deps(),
      docs: docs(),
      description: @description,
      source_url: "https://github.com/ash-project/ash_paper_trail",
      homepage_url: "https://github.com/ash-project/ash_paper_trail"
    ]
  end

  defp package do
    [
      name: :ash_paper_trail,
      licenses: ["MIT"],
      files: ~w(lib .formatter.exs mix.exs README* LICENSE*
      CHANGELOG* documentation),
      links: %{
        GitHub: "https://github.com/ash-project/ash_paper_trail"
      }
    ]
  end

  defp docs do
    [
      main: "get-started-with-paper-trail",
      source_ref: "v#{@version}",
      logo: "logos/small-logo.png",
      extra_section: "GUIDES",
      extras: [
        "documentation/tutorials/get-started-with-paper-trail.md"
      ],
      groups_for_extras: [
        Tutorials: ~r'documentation/tutorials',
        "How To": ~r'documentation/how_to',
        Topics: ~r'documentation/topics',
        DSLs: ~r'documentation/dsls'
      ],
      before_closing_head_tag: fn type ->
        if type == :html do
          """
          <script>
            if (location.hostname === "hexdocs.pm") {
              var script = document.createElement("script");
              script.src = "https://plausible.io/js/script.js";
              script.setAttribute("defer", "defer")
              script.setAttribute("data-domain", "ashhexdocs")
              document.head.appendChild(script);
            }
          </script>
          """
        end
      end
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
      {:ash, "~> 2.18"},
      {:ex_doc, "~> 0.22", only: [:dev, :test], runtime: false},
      {:ex_check, "~> 0.12", only: [:dev, :test]},
      {:credo, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:dialyxir, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:sobelow, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:git_ops, "~> 2.5", only: [:dev, :test]},
      {:excoveralls, "~> 0.13", only: [:dev, :test]}
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
