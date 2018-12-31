# Hammer.Backend.Mnesia

[![Build Status](https://travis-ci.org/ExHammer/hammer-backend-mnesia.svg?branch=master)](https://travis-ci.org/ExHammer/hammer-backend-mnesia)

An Mnesia backend for the [Hammer](https://github.com/ExHammer/hammer)
rate-limiter.

This package is under development and should not be used until an official
release is published.


## Todo

- [x] More options to create-table
- [x] Move the prune into a separate spin-off process
  - [ ] And make sure there's only one at a time?
- [ ] Documentation
  - [x] Module docs
  - [x] Generate docs
  - [ ] Getting-started guide
    - [ ] How to set up Mnesia
- [x] Publish v0.5 (initial release)
- [x] Test with load-test app


## Installation

Hammer-backend-mnesia
is [available in Hex](https://hex.pm/packages/hammer_backend_mnesia), the package
can be installed by adding `hammer_backend_mnesia` to your list of dependencies in `mix.exs`:


```elixir
def deps do
  [{:hammer_backend_mnesia, "~> 0.5"},
   {:hammer, "~> 6.0"}]
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
