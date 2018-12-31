# A Mnesia backend for the Hammer rate-limiter

[Hammer](https://github.com/ExHammer/hammer) is a rate-limiter for
the [Elixir](https://elixir-lang.org/) language. It's killer feature is a
pluggable backend system, allowing you to use whichever storage suits your
needs.

This package provides a Mnesia backend for Hammer, storing rate-limit counters in an Mnesia table.

To get started, read
the [Hammer Tutorial](https://hexdocs.pm/hammer/tutorial.html) first, then add
the `hammer_backend_mnesia` dependency:

```elixir
    def deps do
      [{:hammer_backend_mnesia, "~> 0.5"},
      {:hammer, "~> 6.0"}]
    end
```

... then configure the `:hammer` application to use the Redis backend:

```elixir
config :hammer,
  backend: {Hammer.Backend.Mnesia, [expiry_ms: 60_000 * 60 * 2,
                                    cleanup_interval_ms: 60_000 * 15]}
```
