defmodule Dotenvy.MixProject do
  use Mix.Project

  @source_url "https://github.com/fireproofsocks/dotenvy"
  @version "0.3.0"

  def project do
    [
      app: :dotenvy,
      name: "Dotenvy",
      description: description(),
      version: @version,
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      package: package(),
      elixirc_paths: elixirc_paths(Mix.env()),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [coveralls: :test, "coveralls.detail": :test],
      docs: [
        main: "readme",
        source_ref: "v#{@version}",
        source_url: @source_url,
        logo: "assets/logo.png",
        extras: extras()
      ]
    ]
  end

  def extras do
    [
      "README.md",
      "CHANGELOG.md",
      "docs/dotenv-file-format.md",
      "docs/strategies.md"
    ]
  end

  defp description do
    """
    Dotenvy is an Elixir implementation of the original dotenv Ruby gem, compatible
    with mix and releases. It is designed to facilitate runtime configuration per the
    guidelines of the 12-factor App.
    """
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp package do
    [
      maintainers: ["Everett Griffiths"],
      licenses: ["Apache 2.0"],
      logo: "assets/logo.png",
      links: links(),
      files: [
        "lib",
        "assets/logo.png",
        "mix.exs",
        "README*",
        "CHANGELOG*",
        "LICENSE*"
      ]
    ]
  end

  def links do
    %{
      "GitHub" => @source_url,
      "Readme" => "#{@source_url}/blob/v#{@version}/README.md",
      "Changelog" => "#{@source_url}/blob/v#{@version}/CHANGELOG.md"
    }
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp aliases do
    [
      lint: ["format --check-formatted", "credo --strict"]
    ]
  end

  defp deps do
    [
      {:credo, "~> 1.4", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false},
      {:ex_doc, "~> 0.24.0", only: :dev, runtime: false},
      {:excoveralls, "~> 0.13", only: [:dev, :test], runtime: false},
      {:mox, "~> 1.0.0", only: [:test], runtime: false}
    ]
  end
end
