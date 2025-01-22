defmodule Hammer.Mnesia.LeakyBucket do
  @moduledoc """
  This module implements the Leaky Bucket algorithm.

  The leaky bucket algorithm works by modeling a bucket that:
  - Fills up with requests at the input rate
  - "Leaks" requests at a constant rate
  - Has a maximum capacity (the bucket size)

  For example, with a leak rate of 10 requests/second and bucket size of 100:
  - Requests add to the bucket's current level
  - The bucket leaks 10 requests per second steadily
  - If bucket reaches capacity (100), new requests are denied
  - Once bucket level drops, new requests are allowed again

  ## The algorithm:
  1. When a request comes in, we:
     - Calculate how much has leaked since last request
     - Subtract leaked amount from current bucket level
     - Try to add new request to bucket
     - Store new bucket level and timestamp
  2. To check if rate limit is exceeded:
     - If new bucket level <= capacity: allow request
     - If new bucket level > capacity: deny and return time until enough leaks
  3. Old entries are automatically cleaned up after expiration

  This provides smooth rate limiting with ability to handle bursts up to bucket size.

  The leaky bucket is a good choice when:

  - You need to enforce a constant processing rate
  - Want to allow temporary bursts within bucket capacity
  - Need to smooth out traffic spikes
  - Want to prevent resource exhaustion

  ## Common use cases include:

  - API rate limiting needing consistent throughput
  - Network traffic shaping
  - Service protection from sudden load spikes
  - Queue processing rate control
  - Scenarios needing both burst tolerance and steady-state limits

  The main advantages are:
  - Smooth, predictable output rate
  - Configurable burst tolerance
  - Natural queueing behavior

  The tradeoffs are:
  - More complex implementation than fixed windows
  - Need to track last request time and current bucket level
  - May need tuning of bucket size and leak rate parameters

  For example, with 100 requests/sec limit and 500 bucket size:
  - Can handle bursts of up to 500 requests
  - But long-term average rate won't exceed 100/sec
  - Provides smoother traffic than fixed windows

  The leaky bucket algorithm supports the following options:

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
        use Hammer, backend: Hammer.Mnesia, algorithm: :leaky_bucket
      end

      MyApp.RateLimit.start_link(clean_period: :timer.minutes(1))

      # Allow 100 requests/sec leak rate with max capacity of 500
      MyApp.RateLimit.hit("user_123", 100, 500, 1)
  """

  require Logger

  @doc false
  @spec mnesia_opts() :: list()
  def mnesia_opts do
    [
      type: :set,
      attributes: [:key, :count, :last_updated]
    ]
  end

  @doc """
  Checks if a key is allowed to perform an action, and increment the counter by the given amount.
  """
  @spec hit(
          table :: atom(),
          key :: String.t(),
          leak_rate :: pos_integer(),
          capacity :: pos_integer(),
          cost :: pos_integer()
        ) :: {:allow, non_neg_integer()} | {:deny, non_neg_integer()}
  def hit(table, key, leak_rate, capacity, cost) do
    now = System.system_time(:second)

    result =
      :mnesia.transaction(fn ->
        case :mnesia.read(table, key) do
          [] ->
            # First hit
            record = {table, key, cost, now}
            :mnesia.write(table, record, :write)
            {:allow, cost}

          [record] ->
            time_elapsed = now - elem(record, 3)
            leaked = floor(time_elapsed / leak_rate)
            new_count = max(0, elem(record, 2) - leaked) + cost

            if new_count <= capacity do
              new_record = {table, key, new_count, now}

              :mnesia.write(table, new_record, :write)
              {:allow, new_count}
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
  @spec get(table :: atom(), key :: String.t()) :: non_neg_integer()
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
