defmodule Hammer.Mnesia.TokenBucket do
  @moduledoc """
  This module implements the Token Bucket algorithm.
  The token bucket algorithm works by modeling a bucket that:
  - Fills with tokens at a constant rate (the refill rate)
  - Has a maximum capacity of tokens (the bucket size)
  - Each request consumes one or more tokens
  - If there are enough tokens, the request is allowed
  - If not enough tokens, the request is denied

  For example, with a refill rate of 10 tokens/second and bucket size of 100:
  - Tokens are added at 10 per second up to max of 100
  - Each request needs tokens to proceed
  - If bucket has enough tokens, request allowed and tokens consumed
  - If not enough tokens, request denied until bucket refills

  ## The algorithm:
  1. When a request comes in, we:
     - Calculate tokens added since last request based on time elapsed
     - Add new tokens to bucket (up to max capacity)
     - Try to consume tokens for the request
     - Store new token count and timestamp
  2. To check if rate limit is exceeded:
     - If enough tokens: allow request and consume tokens
     - If not enough: deny and return time until enough tokens refill
  3. Old entries are automatically cleaned up after expiration

  This provides smooth rate limiting with ability to handle bursts up to bucket size.
  The token bucket is a good choice when:

  - You need to allow temporary bursts of traffic
  - Want to enforce an average rate limit
  - Need to support different costs for different operations
  - Want to avoid the sharp edges of fixed windows

  ## Common use cases include:

  - API rate limiting with burst tolerance
  - Network traffic shaping
  - Resource allocation control
  - Gaming systems with "energy" mechanics
  - Scenarios needing flexible rate limits

  The main advantages are:
  - Natural handling of bursts
  - Flexible token costs for different operations
  - Smooth rate limiting behavior
  - Simple to reason about

  The tradeoffs are:
  - Need to track token count and last update time
  - May need tuning of bucket size and refill rate
  - More complex than fixed windows

  For example with 100 tokens/minute limit and 500 bucket size:
  - Can handle bursts using saved up tokens
  - Automatically smooths out over time
  - Different operations can cost different amounts
  - More flexible than fixed request counts

  The token bucket algorithm supports the following options:

  - `:clean_period` - How often to run the cleanup process (in milliseconds)
    Defaults to 1 minute. The cleanup process removes expired bucket entries.

  - `:key_older_than` - Optional maximum age for bucket entries (in milliseconds)
    If set, entries older than this will be removed during cleanup.
    This helps prevent memory growth from abandoned buckets.

  ## Example
  ### Example configuration:

      MyApp.RateLimit.start_link(
        clean_period: :timer.minutes(5),
        key_older_than: :timer.minutes(10)
      )

  This would run cleanup every 5 minutes and remove buckets not used in 24 hours.

  ### Example usage:

      defmodule MyApp.RateLimit do
        use Hammer, backend: Hammer.Mnesia, algorithm: :token_bucket
      end

      MyApp.RateLimit.start_link(clean_period: :timer.minutes(1))

      # Allow 10 tokens per second with max capacity of 100
      MyApp.RateLimit.hit("user_123", 10, 100, 1)
  """

  require Logger

  @doc false
  @spec mnesia_opts() :: list()
  def mnesia_opts do
    [
      type: :set,
      attributes: [:key, :tokens, :last_updated]
    ]
  end

  @doc false
  @spec hit(
          table :: atom(),
          key :: term(),
          refill_rate :: pos_integer(),
          capacity :: pos_integer(),
          cost :: pos_integer()
        ) :: {:allow, non_neg_integer()} | {:deny, non_neg_integer()}

  # credo:disable-for-next-line Credo.Check.Refactor.Nesting
  def hit(table, key, refill_rate, capacity, cost \\ 1) do
    now = System.system_time(:second)

    result =
      :mnesia.transaction(fn ->
        case :mnesia.read(table, key) do
          [] ->
            # First hit
            record = {table, key, capacity - cost, now}
            :mnesia.write(table, record, :write)
            {:allow, capacity - cost}

          [record] ->
            new_tokens = trunc((now - elem(record, 3)) * refill_rate)
            current_tokens = min(capacity, elem(record, 2) + new_tokens)

            if current_tokens >= cost do
              final_level = current_tokens - cost
              new_record = {table, key, final_level, now}

              :mnesia.write(table, new_record, :write)
              {:allow, final_level}
            else
              {:deny, 1000}
            end
        end
      end)

    case result do
      {:atomic, response} ->
        response

      {:aborted, reason} ->
        Logger.error("Leaky bucket transaction aborted: #{inspect(reason)}")
        {:deny, 1000}
    end
  end

  @doc """
  Returns the current level of the bucket for a given key.
  """
  @spec get(table :: atom(), key :: term()) :: non_neg_integer()
  def get(table, key) do
    result =
      :mnesia.transaction(fn ->
        case :mnesia.read(table, key) do
          [] ->
            0

          [record] ->
            elem(record, 2)
        end
      end)

    case result do
      {:atomic, response} ->
        response

      {:aborted, reason} ->
        Logger.error("Unable to read key: #{inspect(reason)}")
        0
    end
  end

  @spec clean(config :: keyword()) :: :ok
  def clean(config) do
    now = System.system_time(:second)
    older_than = now - round(config.key_older_than / 1000)
    # generated with `:ets.fun2ms(fn {table, key, count, ts} when ts < 123 -> key end)`
    ms = [{{:"$1", :"$2", :"$3", :"$4"}, [{:"=<", :"$4", {:const, older_than}}], [:"$2"]}]

    expired_keys = :mnesia.dirty_select(config.table, ms)
    Enum.each(expired_keys, fn key -> :mnesia.dirty_delete(config.table, key) end)
  end
end
