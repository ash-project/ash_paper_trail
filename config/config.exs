import Config

if Mix.env() == :dev do
  config :git_ops,
    mix_project: Ash.MixProject,
    changelog_file: "CHANGELOG.md",
    repository_url: "https://github.com/ash-project/ash_paper_trail",
    # Instructs the tool to manage your mix version in your `mix.exs` file
    # See below for more information
    manage_mix_version?: true,
    # Instructs the tool to manage the version in your README.md
    # Pass in `true` to use `"README.md"` or a string to customize
    manage_readme_version: "README.md",
    version_tag_prefix: "v"
end

if Mix.env() == :test do
  config :ash, :disable_async?, true


  config :ash_paper_trail,
    ecto_repos: [AshPaperTrail.Test.Repo]

  config :ash_paper_trail, ash_apis: [AshPaperTrail.Test.Api]

  config :ash_paper_trail, AshPaperTrail.Test.Repo,
    username: "postgres",
    password: "postgres",
    hostname: "localhost",
    database: "ash_papertrail_test_db",
    pool: Ecto.Adapters.SQL.Sandbox,
    pool_size: 10
end
