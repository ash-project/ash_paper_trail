defmodule AshPaperTrail.MixProject do
  use Mix.Project

  @version "0.3.1"

  @description """
  The extension for keeping an audit log of changes to your Ash resources.
  """

  def project do
    [
      app: :ash_paper_trail,
      version: @version,
      elixir: "~> 1.14",
      aliases: aliases(),
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      consolidate_protocols: Mix.env() == :prod,
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
      main: "readme",
      source_ref: "v#{@version}",
      logo: "logos/small-logo.png",
      extra_section: "GUIDES",
      extras: [
        {"README.md", title: "Home"},
        "documentation/tutorials/getting-started-with-ash-paper-trail.md",
        "documentation/dsls/DSL-AshPaperTrail.Resource.md",
        "documentation/dsls/DSL-AshPaperTrail.Domain.md",
        "CHANGELOG.md"
      ],
      groups_for_extras: [
        Tutorials: ~r'documentation/tutorials',
        "How To": ~r'documentation/how_to',
        Topics: ~r'documentation/topics',
        DSLs: ~r'documentation/dsls',
        "About AshPaperTrail": [
          "CHANGELOG.md"
        ]
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
      {:ash, ash_version("~> 3.0")},
      {:ex_doc, "~> 0.22", only: [:dev, :test], runtime: false},
      {:ex_check, "~> 0.12", only: [:dev, :test]},
      {:credo, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:dialyxir, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:sobelow, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:git_ops, "~> 2.5", only: [:dev, :test]},
      {:excoveralls, "~> 0.13", only: [:dev, :test]},
      {:mix_audit, ">= 0.0.0", only: [:dev, :test], runtime: false}
    ]
  end

  defp ash_version(default_version) do
    case System.get_env("ASH_VERSION") do
      nil -> default_version
      "local" -> [path: "../ash"]
      "main" -> [git: "https://github.com/ash-project/ash.git"]
      version -> "~> #{version}"
    end
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
        "spark.formatter --extensions AshPaperTrail.Resource,AshPaperTrail.Domain",
      "spark.cheat_sheets_in_search":
        "spark.cheat_sheets_in_search --extensions AshPaperTrail.Resource,AshPaperTrail.Domain",
      "spark.cheat_sheets":
        "spark.cheat_sheets --extensions AshPaperTrail.Resource,AshPaperTrail.Domain"
    ]
  end
end
