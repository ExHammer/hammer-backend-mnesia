# Hammer.Backend.Mnesia

[![Build Status](https://github.com/ExHammer/hammer-backend-mnesia/actions/workflows/ci.yml/badge.svg)](https://github.com/ExHammer/hammer-backend-mnesia/actions/workflows/ci.yml) [![Hex.pm](https://img.shields.io/hexpm/v/hammer_backend_mnesia.svg)](https://hex.pm/packages/hammer_backend_mnesia) [![Documentation](https://img.shields.io/badge/documentation-gray)](https://hexdocs.pm/hammer_backend_mnesia)
[![Total Download](https://img.shields.io/hexpm/dt/hammer_backend_mnesia.svg)](https://hex.pm/packages/hammer_backend_mnesia)
[![License](https://img.shields.io/hexpm/l/hammer_backend_mnesia.svg)](https://github.com/ExHammer/hammer-backend-mnesia/blob/master/LICENSE.md)

An Mnesia backend for the [Hammer](https://github.com/ExHammer/hammer)
rate-limiter.

This package is available in beta. If you have any problems, please open an issue.


## Installation

Hammer-backend-mnesia
is [available in Hex](https://hex.pm/packages/hammer_backend_mnesia), the package
can be installed by adding `hammer_backend_mnesia` to your list of dependencies in `mix.exs`:


```elixir
def deps do
  [{:hammer_backend_mnesia, "~> 0.6"},
   {:hammer, "~> 6.1"}]
end
```


## Usage

First, set up an Mnesia schema, see this guide:  https://elixirschool.com/en/lessons/specifics/mnesia/

Then, create the Mnesia table for Hammer to use:

```elixir
Hammer.Backend.Mnesia.create_mnesia_table()
```

Configure the `:hammer` application to use the Mnesia backend:

```elixir
config :hammer,
  backend: {Hammer.Backend.Mnesia, [expiry_ms: 60_000 * 60 * 2,
                                    cleanup_interval_ms: 60_000 * 10]}
```

And that's it, calls to `Hammer.check_rate/3` and so on will use Mnesia to store
the rate-limit counters.

See the [Hammer Tutorial](https://hexdocs.pm/hammer/tutorial.html) for more.



## Documentation

On hexdocs:
[https://hexdocs.pm/hammer_backend_mnesia/](https://hexdocs.pm/hammer_backend_mnesia/)


## Getting Help

If you're having trouble, either open an issue on this repo, or reach out to the
maintainers ([@shanekilkelly](https://twitter.com/shanekilkelly)) on Twitter.
