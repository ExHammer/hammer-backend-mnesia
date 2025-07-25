## 0.7.1 - 2025-07-23

### Fixed

- Fix typespec to use term() for key parameter in leaky_bucket and token_bucket

## 0.7.0 - 2025-02-06

- Release candidate for 7.0.0. See [upgrade to v7](https://hexdocs.pm/hammer/upgrade-v7.html) for upgrade instructions.

## 0.7.0-rc.1 - 2025-01-09

### Changed

- update to the latest version of Hammer RC4

## 0.7.0-rc.0 - 2025-01-07

### Changed

- adapt to the new Hammer API
- Added `:algorithm` option to the Atomic backend with support for:
  - `:fix_window` (default) - Fixed time window rate limiting
  - `:leaky_bucket` - Constant rate limiting with burst capacity
  - `:token_bucket` - Token-based rate limiting with burst capacity
- use [`:mnesia.dirty_update_counter/3`](https://www.erlang.org/doc/apps/mnesia/mnesia.html#dirty_update_counter/3)
- automatically create an in-memory table (no schema needed)
- listen for cluster changes and replicate the in-memory table
- require Elixir 1.14+ and OTP 25+

## 0.6.1 - 2024-03-29

### Changed

- loosen dependencies

## 0.6.0 - 2024-11-27

### Changed

- Update Dependencies
- Clean code
- Support only for Elixir 1.12 and above

## 0.5.0 - 2018-12-31

Initial release.
