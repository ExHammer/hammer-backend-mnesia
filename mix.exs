defmodule Hammer.Backend.Mnesia.MixProject do
  use Mix.Project

  @version "0.7.0-rc.0"

  def project do
    [
      app: :hammer_backend_mnesia,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      description: "Mnesia backend for Hammer rate-limiter",
      source_url: "https://github.com/ExHammer/hammer-backend-mnesia",
      homepage_url: "https://github.com/ExHammer/hammer-backend-mnesia",
      docs: docs(),
      deps: deps(),
      package: package(),
      test_coverage: [summary: [threshold: 90]]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :mnesia]
    ]
  end

  def docs do
    [
      main: "readme",
      extras: ["README.md", "CHANGELOG.md"],
      source_ref: "v#{@version}"
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:credo, "~> 1.6", only: [:dev, :test]},
      {:dialyxir, "~> 1.1", only: [:dev], runtime: false},
      {:ex_doc, "~> 0.29", only: :dev},
      {:hammer, github: "ruslandoga/hammer", branch: "just-use"}
    ]
  end

  defp package do
    [
      name: :hammer_backend_mnesia,
      maintainers: ["Emmanuel Pinault", "June Kelly"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/ExHammer/hammer-backend-mnesia",
        "Changelog" =>
          "https://github.com/ExHammer/hammer-backend-mnesia/blob/master/CHANGELOG.md"
      }
    ]
  end
end
