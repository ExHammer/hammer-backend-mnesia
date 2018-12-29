# Hammer.Backend.Mnesia

An Mnesia backend for the [Hammer](https://github.com/ExHammer/hammer) rate-limiter.

This package is under development and should not be used until an official release
is published.


## Todo

- [ ] More options to create-table
- [x] Move the prune into a separate spin-off process
  - [ ] And make sure there's only one at a time?
- [ ] Documentation
  - [ ] Module docs
  - [ ] Generate docs
  - [ ] Getting-started guide
    - [ ] How to set up Mnesia
- [ ] Publish v0.1


## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `hammer_backend_mnesia` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:hammer_backend_mnesia, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/hammer_backend_mnesia](https://hexdocs.pm/hammer_backend_mnesia).
