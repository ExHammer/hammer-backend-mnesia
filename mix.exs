defmodule Hammer.Backend.Mnesia.MixProject do
  use Mix.Project

  @version "0.6.0"

  def project do
    [
      app: :hammer_backend_mnesia,
      version: "#{@version}",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      description: "Mnesia backend for Hammer rate-limiter",
      package: [
        name: :hammer_backend_mnesia,
        maintainers: ["Emmanuel Pinault", "Shane Kilkelly (shane@kilkelly.me)"],
        licenses: ["MIT"],
        links: %{
          "GitHub" => "https://github.com/ExHammer/hammer-backend-mnesia",
          "Changelog" =>
            "https://github.com/ExHammer/hammer-backend-mnesia/blob/master/CHANGELOG.md"
        }
      ],
      source_url: "https://github.com/ExHammer/hammer-backend-mnesia",
      homepage_url: "https://github.com/ExHammer/hammer-backend-mnesia",
      docs: docs(),
      deps: deps(),
      test_coverage: [summary: [threshold: 75]]
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
      main: "overview",
      extras: ["guides/Overview.md", "CHANGELOG.md"],
      source_ref: "v#{@version}",
      main: "overview",
      formatters: ["html", "epub"]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:credo, "~> 1.6", only: [:dev, :test]},
      {:dialyxir, "~> 1.1", only: [:dev], runtime: false},
      {:ex_doc, "~> 0.29", only: :dev},
      {:hammer, "~> 6.1.0"}
    ]
  end
end
