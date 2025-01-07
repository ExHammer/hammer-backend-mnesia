# Hammer.Mnesia

[![Build Status](https://github.com/ExHammer/hammer-backend-mnesia/actions/workflows/ci.yml/badge.svg)](https://github.com/ExHammer/hammer-backend-mnesia/actions/workflows/ci.yml)
[![Hex.pm](https://img.shields.io/hexpm/v/hammer_backend_mnesia.svg)](https://hex.pm/packages/hammer_backend_mnesia)
[![Documentation](https://img.shields.io/badge/documentation-gray)](https://hexdocs.pm/hammer_backend_mnesia)
[![Total Download](https://img.shields.io/hexpm/dt/hammer_backend_mnesia.svg)](https://hex.pm/packages/hammer_backend_mnesia)
[![License](https://img.shields.io/hexpm/l/hammer_backend_mnesia.svg)](https://github.com/ExHammer/hammer-backend-mnesia/blob/master/LICENSE.md)


---

> [!NOTE]
>
> This README is for the unreleased master branch, please reference the [official documentation on hexdocs](https://hexdocs.pm/hammer_backend_mnesia/) for the latest stable release.

---

A Mnesia backend for the [Hammer](https://github.com/ExHammer/hammer) rate-limiter.

This package is available in beta. If you have any problems, please open an issue.

> [!TIP]
> Consider using `Hammer.ETS` with counter increments broadcasted via [Phoenix PubSub](https://hexdocs.pm/phoenix_pubsub/Phoenix.PubSub.html) instead.

## Installation

The package can be installed by adding `hammer_backend_mnesia` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:hammer_backend_mnesia, "~> 0.7.0"},
  ]
end
```

## Usage

1. Define the rate limiter using `Hammer.Mnesia` backend:

    ```elixir
    defmodule MyApp.RateLimit do
      use Hammer, backend: Hammer.Mnesia
    end
    ```

2. Add the rate limiter to your supervision tree:

    ```elixir
    children = [
      # ...
      {MyApp.RateLimit, clean_period: :timer.minutes(1)}
      # ...
    ]
    ```

3. And that's it, calls to the rate limiter will use Mnesia to store the counters.

    ```elixir
    case MyApp.RateLimit.hit(key, _scale = :timer.minutes(1), _limit = 100) do
      {:allow, _count} -> :ok
      {:deny, retry_after} -> {:error, :rate_limit, "retry after #{retry_after}ms"}
    end
    ```

## Documentation

On hexdocs: [https://hexdocs.pm/hammer_backend_mnesia/](https://hexdocs.pm/hammer_backend_mnesia/)

## Getting Help

If you're having trouble, either open an issue on this repo, or reach out to the
maintainers ([@shanekilkelly](https://twitter.com/shanekilkelly)) on Twitter.
