defmodule Hammer.Mnesia.FixWindow do
  @moduledoc """
  This module implements the Fix Window algorithm for the [Mnesia](https://hex.pm/packages/mnesia) backend.

  The fixed window algorithm works by dividing time into fixed intervals or "windows"
  of a specified duration (scale). Each window tracks request counts independently.

  For example, with a 60 second window:
  - Window 1: 0-60 seconds
  - Window 2: 60-120 seconds
  - And so on...

  The algorithm:
  1. When a request comes in, we:
     - Calculate which window it belongs to based on current time
     - Increment the counter for that window
     - Store expiration time as end of window
  2. To check if rate limit is exceeded:
     - If count <= limit: allow request
     - If count > limit: deny and return time until window expires
  3. Old windows are automatically cleaned up after expiration

  This provides simple rate limiting but has edge cases where a burst of requests
  spanning a window boundary could allow up to 2x the limit in a short period.
  For more precise limiting, consider using the sliding window algorithm instead.

  The fixed window algorithm is a good choice when:

  - You need simple, predictable rate limiting with clear time boundaries
  - The exact precision of the rate limit is not critical
  - You want efficient implementation with minimal storage overhead
  - Your use case can tolerate potential bursts at window boundaries

  Common use cases include:

  - Basic API rate limiting where occasional bursts are acceptable
  - Protecting backend services from excessive load
  - Implementing fair usage policies
  - Scenarios where clear time-based quotas are desired (e.g. "100 requests per minute")

  The main tradeoff is that requests near window boundaries can allow up to 2x the
  intended limit in a short period. For example with a limit of 100 per minute:
  - 100 requests at 11:59:59
  - Another 100 requests at 12:00:01

  This results in 200 requests in 2 seconds, while still being within limits.
  If this behavior is problematic, consider using the sliding window algorithm instead.

  The fixed window algorithm supports the following options:

  - `:clean_period` - How often to run the cleanup process (in milliseconds)
    Defaults to 1 minute. The cleanup process removes expired window entries.

  Example configuration:

      MyApp.RateLimit.start_link(
        clean_period: :timer.minutes(5),
      )

  This would run cleanup every 5 minutes and clean up old windows.
  """

  alias Hammer.Mnesia

  @spec mnesia_opts() :: list()
  def mnesia_opts do
    [
      type: :set,
      attributes: [:key, :count]
    ]
  end

  @doc false
  @spec hit(
          table :: atom(),
          key :: term(),
          scale :: non_neg_integer(),
          limit :: non_neg_integer(),
          increment :: non_neg_integer()
        ) ::
          {:allow, non_neg_integer()} | {:deny, non_neg_integer()}
  def hit(table, key, scale, limit, increment) do
    now = Mnesia.now()
    full_key = full_key(key, scale, now)
    count = :mnesia.dirty_update_counter(table, full_key, increment)

    if count <= limit do
      {:allow, count}
    else
      {_, _, expires_at} = full_key
      retry_after = max(expires_at - now, 0)
      {:deny, retry_after}
    end
  end

  @doc false
  @spec inc(
          table :: atom(),
          key :: term(),
          scale :: non_neg_integer(),
          increment :: non_neg_integer()
        ) :: non_neg_integer()
  def inc(table, key, scale, increment) do
    :mnesia.dirty_update_counter(table, full_key(key, scale), increment)
  end

  @doc false
  @spec set(
          table :: atom(),
          key :: term(),
          scale :: non_neg_integer(),
          count :: non_neg_integer()
        ) :: non_neg_integer()
  def set(table, key, scale, count) do
    full_key = full_key(key, scale)
    current_count = :mnesia.dirty_update_counter(table, full_key, 0)
    :mnesia.dirty_update_counter(table, full_key, count - current_count)
  end

  @doc false
  @spec get(table :: atom(), key :: term(), scale :: non_neg_integer()) :: non_neg_integer()
  def get(table, key, scale) do
    :mnesia.dirty_update_counter(table, full_key(key, scale), 0)
  end

  @compile inline: [full_key: 2]
  def full_key(key, scale) do
    full_key(key, scale, Mnesia.now())
  end

  @compile inline: [full_key: 3]
  def full_key(key, scale, now) do
    window = div(now, scale)
    expires_at = (window + 1) * scale
    {key, window, expires_at}
  end

  @spec clean(config :: keyword()) :: :ok
  def clean(config) do
    # generated with `:ets.fun2ms fn {_, {k, w, e}, _} when e < 123 -> {k, w, e} end`
    ms = [
      {{:_, {:"$1", :"$2", :"$3"}, :_}, [{:<, :"$3", {:const, Mnesia.now()}}],
       [{{:"$1", :"$2", :"$3"}}]}
    ]

    expired_keys = :mnesia.dirty_select(config.table, ms)
    Enum.each(expired_keys, fn key -> :mnesia.dirty_delete(config.table, key) end)
  end
end
