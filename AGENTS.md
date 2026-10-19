# AGENTS.md

`hammer_backend_mnesia` is a small Elixir library (published on Hex) that plugs an in-memory Mnesia table into [Hammer](https://github.com/ExHammer/hammer) v7 as a rate-limiting backend. Application developers use it via `use Hammer, backend: Hammer.Mnesia`. It is a library: there is no Phoenix, Ecto, Repo, release, or deploy target. Output is a Hex package plus HexDocs. The `origin` remote is `git@github.com:ExHammer/hammer-backend-mnesia`, i.e. the **upstream ExHammer repo** (not a personal fork); default branch is `master`.

## Project Overview

| Item | Value |
|---|---|
| App / package | `:hammer_backend_mnesia` v0.7.1 (`@version` in `mix.exs`) |
| Top module | `Hammer.Mnesia` (project module is `Hammer.Backend.Mnesia.MixProject`) |
| Elixir (declared) | `~> 1.14` (OTP 25+) |
| Elixir / OTP (local toolchain) | 1.20.4 / 29.0.6 (`.tool-versions`, `mise.toml`) |
| Hammer | `~> 7.0` (lockfile has 7.5.0) |
| Storage | `:mnesia` (in `extra_applications`), RAM-only tables, no schema/disc |
| Dev/test deps | credo ~> 1.7, dialyxir ~> 1.4 (dev only), ex_doc ~> 0.35 (dev only), benchee ~> 1.2 (`:bench` env only) |
| CI | GitHub Actions: `.github/workflows/ci.yml` (matrix Elixir 1.14/OTP25, 1.17/OTP25,26,27, 1.18/OTP27), `publish.yml` (Hex publish on any pushed tag) |
| Coverage | `test_coverage: [summary: [threshold: 85]]` |

## Essential Commands

There are **no custom mix aliases**; there is no `precommit` alias. The quality gate is what CI runs.

```bash
# Setup
mix deps.get

# Test
mix test                                  # slow tests are NOT excluded locally (test_helper is plain ExUnit.start())
mix test --warnings-as-errors --cover --include slow   # exactly what CI runs
mix test test/hammer/mnesia_test.exs
mix test test/hammer/mnesia_test.exs:12   # single line

# Quality gate (run all before committing; mirrors CI)
mix compile --warnings-as-errors
mix credo --strict --format=oneline
mix format --check-formatted
mix deps.unlock --check-unused

# Optional
mix dialyzer                              # dialyxir is dev-only, not in CI
mix docs                                  # ex_doc, dev only

# Benchmark (see header of bench/base.exs)
MIX_ENV=bench LIMIT=1 SCALE=5000 RANGE=10000 PARALLEL=500 mix run bench/base.exs
```

Deploy/publish: tag push triggers Hex publish (see Workflow).

## Architecture

```
lib/hammer/
  mnesia.ex               Hammer.Mnesia: GenServer + __before_compile__ macro that generates hit/inc/set/get in the user's module
  mnesia/
    fix_window.ex         Hammer.Mnesia.FixWindow   (default algorithm; table attrs [:key, :count]; dirty_update_counter)
    leaky_bucket.ex       Hammer.Mnesia.LeakyBucket (attrs [:key, :count, :last_updated]; :mnesia.transaction)
    token_bucket.ex       Hammer.Mnesia.TokenBucket (attrs [:key, :count/tokens, :last_updated]; :mnesia.transaction)
test/
  test_helper.exs                    just ExUnit.start()
  hammer/mnesia_test.exs             fix-window hit/inc/set/get via a test RateLimit module
  hammer/mnesia/leaky_bucket_test.exs
  hammer/mnesia/token_bucket_test.exs
  hammer/mnesia/cleanup_test.exs     @moduletag :slow; sleeps for real clean periods
bench/base.exs                       Benchee script (MIX_ENV=bench only)
```

### How the backend plugs into Hammer

Hammer's `use Hammer, backend: Hammer.Mnesia, ...` stores the opts in `@hammer_opts` and expects the backend module to expose `__before_compile__/1`. (Behaviour is `Hammer` in `/Users/manu/Projects/hammer/lib/hammer.ex`; callbacks: `hit/3`, `hit/4`, `inc/2,3`, `set/3`, `get/2`, `expires_at/2`; all optional except `hit`; read-only reference, do not edit that repo.) `Hammer.Mnesia.__before_compile__/1`:

1. Resolves `:table` (default: the user's module name) and `:algorithm` (`:fix_window` | `:leaky_bucket` | `:token_bucket` | a custom module; default `Hammer.Mnesia.FixWindow`).
2. Generates `child_spec/1`, `start_link/1`, `hit/4`, and conditionally `inc/3`, `set/3`, `get/1`, `get/2` using `function_exported?/3` on the algorithm module. So an algorithm module's public arity decides which functions the user's module gets.

An algorithm module must provide: `mnesia_opts/0` (keyword passed to `:mnesia.create_table/2`, merged over user opts), `hit/5` (`table, key, scale, limit, increment`), and `clean/1` (receives the GenServer state map with `:table`, `:key_older_than`, `:clean_period`, `:algorithm`). `inc`/`set`/`get` are optional.

Return contract of `hit`: `{:allow, count}` or `{:deny, retry_after_ms}`.

### Process / supervision

No `Application` module and no supervision tree of its own. `Hammer.Mnesia` is a GenServer the **user** puts in their tree. `init/1` returns `{:continue, :init}`; `handle_continue(:init, ...)` creates the table (`:already_exists` is tolerated, any other abort raises) and schedules the first `:clean` message via `Process.send_after`. `handle_info(:clean, ...)` calls `algorithm.clean(state)` and reschedules. `:clean_period` is **required** (`Keyword.pop!`); `:key_older_than` defaults to 10 minutes.

### Cleanup / expiry

- FixWindow: key is `{key, window, expires_at}`; clean selects entries whose `expires_at < now` (ms) with `:mnesia.dirty_select` and `dirty_delete`s them. `key_older_than` is ignored here.
- LeakyBucket / TokenBucket: timestamps are in **seconds** (`System.system_time(:second)`); clean deletes records with `last_updated <= now - key_older_than/1000`.
- Note FixWindow timestamps are **milliseconds** (`Hammer.Mnesia.now/0`); buckets are seconds. Do not mix them.

### Concurrency model

FixWindow uses `:mnesia.dirty_update_counter/3` (atomic per-record counter, no transaction). Buckets do read-modify-write inside `:mnesia.transaction/1`; on abort they log and return `{:deny, 1000}` (leaky) / equivalent fail-closed result. Preserve fail-closed behaviour.

## Conventions

- `.formatter.exs` is default (`inputs: ["mix.exs", "{lib,test}/**/*.{ex,exs}"]`): 98-column default line length.
- `.credo.exs` runs `strict: true`. A `# credo:disable-for-next-line` is already used once in `mnesia.ex`; avoid adding more without cause.
- Every public module has a long `@moduledoc` (usage, options, trade-offs). Algorithm entry points use `@doc false` or `@doc` plus `@spec` with named params (`table :: atom()`, `key :: term()`). Keep `key` typed `term()` (0.7.1 fixed this).
- Use `@impl GenServer` on callbacks; hot-path helpers use `@compile inline:`.
- Match specs in `clean/1` are hand-written from `:ets.fun2ms`; keep the generating-fn comment when editing.
- Logging via `Logger` (`require Logger` where used); log aborted transactions with `inspect(reason)`.
- Docs say "ETS" in the `Hammer.Mnesia.start_link/1` doc (copy-paste from the ETS backend); fix if you touch it.

## Testing

- Plain ExUnit, no support dir, no fixtures/factories, no Mox, no Ecto sandbox. `test_helper.exs` is only `ExUnit.start()`.
- **Mnesia is started implicitly** because `:mnesia` is in `extra_applications`. No node name (`--sname`), no tmp dir, no schema creation: tables are `ram_copies` on the default nameless `nonode@nohost` node. Do not introduce disc tables or a schema in tests.
- Each test file defines its own rate limiter module (`defmodule RateLimit do use Hammer, backend: Hammer.Mnesia end`) whose name is the table name, so test modules do not collide. Tests are `async: true`; keep tables unique per module.
- Setup pattern: `start_supervised!({RateLimit, clean_period: :timer.minutes(60)})`, then `Process.sleep(100)` to wait for the `handle_continue` table creation, and `on_exit(fn -> :mnesia.delete_table(RateLimit) end)`. This sleep is a known wart (table creation is async); prefer a deterministic wait (e.g. `:mnesia.wait_for_tables/2`) in new tests rather than copying it.
- `cleanup_test.exs` is tagged `:slow` and really sleeps through clean periods (seconds). CI passes `--include slow`; nothing excludes it locally.
- Example:

```elixir
assert {:allow, 1} = RateLimit.hit("key", :timer.seconds(1), 1)
assert {:deny, retry_after} = RateLimit.hit("key", :timer.seconds(1), 1)
assert [{"key", _, _}] = :mnesia.dirty_all_keys(RateLimit)
```

- CI coverage threshold is 85%; add tests with any new branch.
- Not tested: real multi-node clustering. Verify distribution changes manually (e.g. two `iex --sname` nodes) and say so in the PR.

## Elixir / Mnesia Guidelines

- Supported floor is Elixir 1.14 / OTP 25; do not use newer-only stdlib APIs (check the CI matrix). Local toolchain is 1.20/OTP 29, so a compile locally does not prove 1.14 compatibility.
- Prefer pattern matching and `with`; no nested `case`; tagged tuples for results; no `String.to_atom` on caller input.
- Rate-limit keys are arbitrary terms and are stored directly in Mnesia; never convert them.
- Mnesia specifics:
  - `:mnesia.create_table/2` is called from every node that starts the limiter; `{:aborted, {:already_exists, _}}` must stay a success.
  - Default storage is `ram_copies`. User-supplied mnesia opts (e.g. `ram_copies: [node1, node2]`, `disc_copies`) are passed through `start_link` opts and merged *under* `algorithm.mnesia_opts()` (the algorithm's `type`/`attributes` win).
  - Dirty ops (`dirty_update_counter`, `dirty_select`, `dirty_delete`) are used for speed; they are not isolated and not atomic across multiple records. Use `:mnesia.transaction` when a read-modify-write is needed.
  - Record shape is `{table, key, ...attrs}`; in transactions the record tuple's first element is the table name, which is why `elem(record, 2)` / `elem(record, 3)` index the count / timestamp.
  - Changing `attributes` of an existing algorithm is a breaking schema change for anyone with a persistent table.
- Avoid `Process.sleep` in new tests; for GenServer startup use deterministic waits.
- Use `Req` if HTTP is ever needed (not currently; this library has no HTTP).
- Let the GenServer crash on unexpected table-creation failure (current behaviour: `:erlang.error(reason)`); do not rescue it.

## Workflow for Agents

1. Read the algorithm module you are touching and its test, and, if the contract is involved, `/Users/manu/Projects/hammer/lib/hammer.ex` (read-only).
2. Write or adjust the test first (copy the setup pattern above).
3. Implement.
4. Run the quality gate from Essential Commands (compile with warnings as errors, credo --strict, format check, tests with `--include slow`).
5. User-visible change: add an entry to `CHANGELOG.md` (top of file, newest first, headings like `## 0.7.1 - 2025-07-23` with `### Fixed` / `### Changed`).
6. Commits: git history mixes plain imperative subjects ("Fix typespec ... (#53)") with conventional prefixes (`build(deps): ...`, `ci: ...`) and PR numbers in parentheses. Use conventional commit style. Work on a branch; PRs target `master` on GitHub. Dependabot opens the `Bump ...` PRs.
7. Release (from `RELEASE.md` and workflows): bump `@version` in `mix.exs`, update the version in the README install snippet, add the CHANGELOG entry, run tests and credo, merge to `master`, then push a git tag; `publish.yml` publishes to Hex using the `HEX_API_KEY` secret on any tag. Docs publish with the package. Do not tag or publish unless the user asks.

## Constraints - Never Do

- Never skip the quality gate or use `--no-verify`.
- Never edit `mix.lock` by hand; use `mix deps.update`.
- Never add disc-based tables, `:mnesia.create_schema`, or `:mnesia.start` calls to library code; the app owner controls schema and node setup.
- Never make `hit` fail open on Mnesia errors; keep the fail-closed `{:deny, ...}` pattern.
- Never change a table's `attributes` or record layout without a CHANGELOG note flagged as breaking.
- Never edit files in `/Users/manu/Projects/hammer` from here.
- Never tag, publish to Hex, or bump `@version` without being asked.
- Never commit `IO.inspect`, `IEx.pry`, secrets, or `HEX_API_KEY`.
- Do not add Ecto/Phoenix dependencies; runtime deps are only `hammer` (plus OTP `:mnesia`/`:logger`).

## Gotchas

- `__before_compile__` runs at compile time of the user's module; `Code.ensure_loaded!(algorithm)` means a bad `:algorithm` raises `ArgumentError` at compile time, not runtime.
- The limiter's table is created asynchronously in `handle_continue`; calling `hit/4` immediately after `start_link` can race and fail with `{:aborted, {:no_exists, table}}`-style errors. Tests sleep 100 ms to cover this.
- `mnesia.ex` still has `# TODO listen for cluster changes` and `# TODO attempt unsplit`. CHANGELOG 0.7.0-rc.0 claims "listen for cluster changes and replicate the in-memory table", but the code does not do that; it only calls `create_table`. Replication requires the caller to pass `ram_copies: [nodes]` or manage Mnesia themselves. Treat the CHANGELOG line as aspirational.
- No `:before_clean` hook (available in the Hammer ETS backend as of hammer 7.5) and no `expires_at/2` callback here. Adding them means matching the ETS backend's API in `/Users/manu/Projects/hammer/lib/hammer/ets.ex` and `clean_utils.ex`.
- Moduledoc of `Hammer.Mnesia.start_link/1` mentions an ETS table and `:fixed_window`; the real atom is `:fix_window`.
- Time units differ between FixWindow (ms) and the bucket algorithms (seconds); `key_older_than` is in ms and converted with `round(x / 1000)` for buckets.
- README install snippet says `~> 0.7.0` while `mix.exs` is 0.7.1 (compatible, but keep in step on release).
- `RELEASE.md` contains a typo ("hammer-bakend-mnesia") and is terse.
- CI formatting job uses Elixir 1 / OTP 27, so formatting must be stable across versions.

## Code Search

`sgrep` is a semantic code search tool (ripgrep candidates re-ranked by local embeddings). It may not be installed on every machine: check with `command -v sgrep`; if it is missing, use `rg`/`grep` as usual and do not try to install it.

- Prefer `sgrep "natural-language question" lib/` when you are looking for a concept or behaviour and do not know the exact identifier, when the codebase is unfamiliar, or when `rg` returned too many hits or none because the naming did not match your guess.
- Keep `rg`/`grep` when you know the exact symbol, string, module name or regex, when you need every occurrence (renames, call-site audits), or when matching structured patterns (config keys, log formats, file paths).
- Always pass a directory as the second argument (`lib/`, `test/`, `assets/js/`) so `deps/`, `_build/`, `node_modules/` are skipped. The first run on a corpus builds an embedding index (slow); later runs reuse the cache. Use `--refresh-cache` after large refactors if results look stale.

## Key Files

- `lib/hammer/mnesia.ex` - backend entry point: macro generating the user's API, GenServer lifecycle, table creation, clean scheduling.
- `lib/hammer/mnesia/fix_window.ex` - default algorithm, simplest reference for adding an algorithm.
- `lib/hammer/mnesia/leaky_bucket.ex` - transaction-based algorithm, second-resolution timestamps.
- `lib/hammer/mnesia/token_bucket.ex` - transaction-based algorithm.
- `test/hammer/mnesia_test.exs` - canonical test setup pattern.
- `test/hammer/mnesia/cleanup_test.exs` - expiry tests (slow).
- `/Users/manu/Projects/hammer/lib/hammer.ex` - Hammer behaviour and `use Hammer` macro (read-only).
- `/Users/manu/Projects/hammer/lib/hammer/ets.ex` - sibling backend to mirror for API parity (read-only).
- `mix.exs` - version, deps, Hex package metadata, coverage threshold.
- `.github/workflows/ci.yml` - the real quality gate and Elixir/OTP matrix.
- `.github/workflows/publish.yml`, `RELEASE.md` - release flow.
- `CHANGELOG.md` - must be updated per user-visible change (also included in ExDoc extras).
- `bench/base.exs` - benchmark harness.
