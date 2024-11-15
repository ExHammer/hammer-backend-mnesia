# Hammer.Mnesia

[![Build Status](https://github.com/ExHammer/hammer-backend-mnesia/actions/workflows/ci.yml/badge.svg)](https://github.com/ExHammer/hammer-backend-mnesia/actions/workflows/ci.yml)
[![Hex.pm](https://img.shields.io/hexpm/v/hammer_backend_mnesia.svg)](https://hex.pm/packages/hammer_backend_mnesia)
[![Documentation](https://img.shields.io/badge/documentation-gray)](https://hexdocs.pm/hammer_backend_mnesia)
[![Total Download](https://img.shields.io/hexpm/dt/hammer_backend_mnesia.svg)](https://hex.pm/packages/hammer_backend_mnesia)
[![License](https://img.shields.io/hexpm/l/hammer_backend_mnesia.svg)](https://github.com/ExHammer/hammer-backend-mnesia/blob/master/LICENSE.md)

A Mnesia backend for the [Hammer](https://github.com/ExHammer/hammer) rate-limiter.

By default it uses a single `type: :set` in-memory Mnesia table that is not distributed. See Mnesia documentation for [`create_table/2`](https://www.erlang.org/doc/apps/mnesia/mnesia.html#create_table/2) for more information.

This package is available in beta. If you have any problems, please open an issue.

> [!TIP]
> Consider using ETS tables with counter increments broadcasted over `Phoenix.PubSub` instead.
> 
> That approach is both more performant and less error prone.

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
      # you can add `ram_copies: Node.list()` to make the table distributed, but that requires extra configuration
      {MyApp.RateLimit, clean_period: :timer.minutes(1)}
    ]
    ```

    Note that this process will fail to start if `:mnesia.create_table/2` call fails. Depending on your supervision strategy that can take down the whole application. So be careful with the extra options you provide.

3. And that's it, calls to `MyApp.RateLimit.hit/3` and so on will use Mnesia to store the rate-limit counters.

## Documentation

On hexdocs: [https://hexdocs.pm/hammer_backend_mnesia/](https://hexdocs.pm/hammer_backend_mnesia/)

## Getting Help

If you're having trouble, either open an issue on this repo, or reach out to the
maintainers ([@shanekilkelly](https://twitter.com/shanekilkelly)) on Twitter.
