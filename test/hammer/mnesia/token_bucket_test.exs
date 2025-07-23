defmodule Hammer.Redis.TokenBucketTest do
  use ExUnit.Case, async: true

  defmodule RateLimitTokenBucket do
    use Hammer, backend: Hammer.Mnesia, algorithm: :token_bucket
  end

  setup do
    start_supervised!({RateLimitTokenBucket, clean_period: :timer.minutes(60)})

    # because of handle_continue in GenServer, need to wait for the table to be created
    Process.sleep(100)
    on_exit(fn -> :mnesia.delete_table(RateLimitTokenBucket) end)

    key = "key#{:rand.uniform(1_000_000)}"

    {:ok, %{key: key}}
  end

  describe "hit" do
    test "returns {:allow, 9} tuple on first access", %{key: key} do
      refill_rate = 10
      capacity = 10

      assert {:allow, 9} = RateLimitTokenBucket.hit(key, refill_rate, capacity, 1)
    end

    test "returns {:allow, 6} tuple on in-limit checks", %{key: key} do
      refill_rate = 2
      capacity = 10

      assert {:allow, 9} = RateLimitTokenBucket.hit(key, refill_rate, capacity, 1)
      assert {:allow, 8} = RateLimitTokenBucket.hit(key, refill_rate, capacity, 1)
      assert {:allow, 7} = RateLimitTokenBucket.hit(key, refill_rate, capacity, 1)
      assert {:allow, 6} = RateLimitTokenBucket.hit(key, refill_rate, capacity, 1)
    end

    test "returns expected tuples on mix of in-limit and out-of-limit checks", %{key: key} do
      refill_rate = 1
      capacity = 2

      assert {:allow, 1} = RateLimitTokenBucket.hit(key, refill_rate, capacity, 1)
      assert {:allow, 0} = RateLimitTokenBucket.hit(key, refill_rate, capacity, 1)

      assert {:deny, 1000} = RateLimitTokenBucket.hit(key, refill_rate, capacity, 1)

      assert {:deny, _retry_after} =
               RateLimitTokenBucket.hit(key, refill_rate, capacity, 1)
    end

    test "returns expected tuples after waiting for the next window", %{key: key} do
      refill_rate = 1
      capacity = 2

      assert {:allow, 1} = RateLimitTokenBucket.hit(key, refill_rate, capacity, 1)
      assert {:allow, 0} = RateLimitTokenBucket.hit(key, refill_rate, capacity, 1)

      assert {:deny, retry_after} =
               RateLimitTokenBucket.hit(key, refill_rate, capacity, 1)

      :timer.sleep(retry_after)

      assert {:allow, 0} = RateLimitTokenBucket.hit(key, refill_rate, capacity, 1)

      assert {:deny, _retry_after} =
               RateLimitTokenBucket.hit(key, refill_rate, capacity, 1)
    end
  end

  describe "get" do
    test "get returns the count set for the given key and scale", %{key: key} do
      refill_rate = :timer.seconds(10)
      capacity = 10

      assert RateLimitTokenBucket.get(key) == 0

      assert {:allow, _} = RateLimitTokenBucket.hit(key, refill_rate, capacity, 4)
      assert RateLimitTokenBucket.get(key) == 6

      assert {:allow, _} = RateLimitTokenBucket.hit(key, refill_rate, capacity, 3)
      assert RateLimitTokenBucket.get(key) == 3
    end
  end

  describe "non-string keys" do
    test "works with atom keys" do
      refill_rate = :timer.seconds(10)
      capacity = 10

      assert {:allow, 9} = RateLimitTokenBucket.hit(:atom_key, refill_rate, capacity, 1)
      assert RateLimitTokenBucket.get(:atom_key) == 9
    end

    test "works with tuple keys" do
      refill_rate = :timer.seconds(10)
      capacity = 10
      tuple_key = {:user, 123}

      assert {:allow, 9} = RateLimitTokenBucket.hit(tuple_key, refill_rate, capacity, 1)
      assert RateLimitTokenBucket.get(tuple_key) == 9
    end

    test "works with integer keys" do
      refill_rate = :timer.seconds(10)
      capacity = 10

      assert {:allow, 9} = RateLimitTokenBucket.hit(123, refill_rate, capacity, 1)
      assert RateLimitTokenBucket.get(123) == 9
    end
  end
end
