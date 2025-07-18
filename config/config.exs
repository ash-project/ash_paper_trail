import Config

if Mix.env() == :dev do
  config :git_ops,
    mix_project: AshPaperTrail.MixProject,
    github_handle_lookup?: true,
    changelog_file: "CHANGELOG.md",
    repository_url: "https://github.com/ash-project/ash_paper_trail",
    # Instructs the tool to manage your mix version in your `mix.exs` file
    # See below for more information
    manage_mix_version?: true,
    # Instructs the tool to manage the version in your README.md
    # Pass in `true` to use `"README.md"` or a string to customize
    manage_readme_version: [
      "README.md",
      "documentation/tutorials/getting-started-with-ash-paper-trail.md"
    ],
    version_tag_prefix: "v"
end

if Mix.env() == :test do
  config :logger, level: :warning
  config :ash, :disable_async?, true
  config :ash_paper_trail, :change_tracking_mode, :changes_only
end
