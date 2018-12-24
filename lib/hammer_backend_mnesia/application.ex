defmodule Hammer.Backend.Mnesia.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    # List all child processes to be supervised
    children = [
      # Starts a worker by calling: Hammer.Backend.Mnesia.Worker.start_link(arg)
      # {Hammer.Backend.Mnesia.Worker, arg},
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Hammer.Backend.Mnesia.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
