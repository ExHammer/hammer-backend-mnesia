defmodule Hammer.Backend.Mnesia.MixProject do
  use Mix.Project

  def project do
    [
      app: :hammer_backend_mnesia,
      version: "0.1.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
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
      {:mock, "~> 0.2.0", only: :test},
      {:ex_doc, "~> 0.16", only: :dev},
      {:dialyxir, "~> 0.5", only: [:dev], runtime: false}
    ]
  end
end
