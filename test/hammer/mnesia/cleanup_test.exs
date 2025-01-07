defmodule Hammer.Mnesia.CleanUpTest do
  use ExUnit.Case, async: true

  @moduletag :slow

  defmodule RateLimit do
    use Hammer, backend: Hammer.Mnesia
  end

  defmodule RateLimitLeakyBucket do
    use Hammer, backend: Hammer.Mnesia, algorithm: :leaky_bucket
  end

  defmodule RateLimitTokenBucket do
    use Hammer, backend: Hammer.Mnesia, algorithm: :token_bucket
  end

  test "cleans expired keys for fix window" do
    start_supervised!({RateLimit, clean_period: :timer.seconds(1)})
    # because of handle_continue in GenServer, need to wait for the table to be created
    Process.sleep(100)

    on_exit(fn -> :mnesia.delete_table(RateLimit) end)

    assert {:allow, 1} = RateLimit.hit("key", :timer.seconds(1), 1)
    assert {:deny, retry_after} = RateLimit.hit("key", :timer.seconds(1), 1)

    assert [{"key", _, _}] = :mnesia.dirty_all_keys(RateLimit)

    :timer.sleep(retry_after)
    :timer.sleep(_clean_period = :timer.seconds(1))

    assert :mnesia.dirty_all_keys(RateLimit) == []
  end

  test "cleans expired keys for leaky bucket" do
    start_supervised!(
      {RateLimitLeakyBucket, clean_period: :timer.seconds(1), key_older_than: :timer.seconds(1)}
    )

    # because of handle_continue in GenServer, need to wait for the table to be created
    Process.sleep(100)
    on_exit(fn -> :mnesia.delete_table(RateLimitLeakyBucket) end)

    assert {:allow, 1} = RateLimitLeakyBucket.hit("key", :timer.seconds(1), 1)
    assert {:deny, _retry_after} = RateLimitLeakyBucket.hit("key", :timer.seconds(1), 1)

    assert ["key"] = :mnesia.dirty_all_keys(RateLimitLeakyBucket)

    :timer.sleep(_clean_period = :timer.seconds(2))

    assert :mnesia.dirty_all_keys(RateLimitLeakyBucket) == []
  end

  test "cleans expired keys for token bucket" do
    start_supervised!(
      {RateLimitTokenBucket, clean_period: :timer.seconds(1), key_older_than: :timer.seconds(1)}
    )

    # because of handle_continue in GenServer, need to wait for the table to be created
    Process.sleep(100)
    on_exit(fn -> :mnesia.delete_table(RateLimitTokenBucket) end)

    assert {:allow, 0} = RateLimitTokenBucket.hit("key", :timer.seconds(1), 1)
    assert {:deny, _retry_after} = RateLimitTokenBucket.hit("key", :timer.seconds(1), 1)

    assert ["key"] = :mnesia.dirty_all_keys(RateLimitTokenBucket)

    :timer.sleep(_clean_period = :timer.seconds(2))

    assert :mnesia.dirty_all_keys(RateLimitTokenBucket) == []
  end
end
