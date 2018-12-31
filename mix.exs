defmodule Hammer.Backend.Mnesia.MixProject do
  use Mix.Project

  def project do
    [
      app: :hammer_backend_mnesia,
      version: "0.5.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      description: "Mnesia backend for Hammer rate-limiter",
      package: [
        name: :hammer_backend_mnesia,
        maintainers: ["Shane Kilkelly (shane@kilkelly.me)"],
        licenses: ["MIT"],
        links: %{"GitHub" => "https://github.com/ExHammer/hammer-backend-mnesia"}
      ],
      source_url: "https://github.com/ExHammer/hammer-backend-mnesia",
      homepage_url: "https://github.com/ExHammer/hammer-backend-mnesia",
      docs: [main: "frontpage", extras: ["doc_src/Frontpage.md"]],
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:hammer, "6.0.0"},
      {:ex_doc, "0.18.4", only: :dev}
    ]
  end
end
