defmodule Hammer.Mnesia.LeakyBucketTest do
  use ExUnit.Case, async: true

  defmodule RateLimitLeakyBucket do
    use Hammer, backend: Hammer.Mnesia, algorithm: :leaky_bucket
  end

  setup do
    start_supervised!({RateLimitLeakyBucket, clean_period: :timer.minutes(60)})

    # because of handle_continue in GenServer, need to wait for the table to be created
    Process.sleep(100)

    on_exit(fn -> :mnesia.delete_table(RateLimitLeakyBucket) end)
    key = "key#{:rand.uniform(1_000_000)}"

    {:ok, %{key: key}}
  end

  describe "hit" do
    test "returns {:allow, 1} tuple on first access", %{key: key} do
      leak_rate = :timer.seconds(10)
      capacity = 10

      assert {:allow, 1} = RateLimitLeakyBucket.hit(key, leak_rate, capacity)
    end

    test "returns {:allow, 4} tuple on in-limit checks", %{key: key} do
      leak_rate = 2
      capacity = 10

      assert {:allow, 1} = RateLimitLeakyBucket.hit(key, leak_rate, capacity, 1)
      assert {:allow, 2} = RateLimitLeakyBucket.hit(key, leak_rate, capacity, 1)
      assert {:allow, 3} = RateLimitLeakyBucket.hit(key, leak_rate, capacity, 1)
      assert {:allow, 4} = RateLimitLeakyBucket.hit(key, leak_rate, capacity, 1)
    end

    test "returns expected tuples on mix of in-limit and out-of-limit checks", %{key: key} do
      leak_rate = 1
      capacity = 2

      assert {:allow, 1} = RateLimitLeakyBucket.hit(key, leak_rate, capacity, 1)
      assert {:allow, 2} = RateLimitLeakyBucket.hit(key, leak_rate, capacity, 1)

      assert {:deny, 1000} =
               RateLimitLeakyBucket.hit(key, leak_rate, capacity, 1)

      assert {:deny, _retry_after} =
               RateLimitLeakyBucket.hit(key, leak_rate, capacity, 1)
    end

    test "returns expected tuples after waiting for the next window", %{key: key} do
      leak_rate = 1
      capacity = 2

      assert {:allow, 1} = RateLimitLeakyBucket.hit(key, leak_rate, capacity, 1)
      assert {:allow, 2} = RateLimitLeakyBucket.hit(key, leak_rate, capacity, 1)

      assert {:deny, retry_after} =
               RateLimitLeakyBucket.hit(key, leak_rate, capacity, 1)

      :timer.sleep(retry_after)

      assert {:allow, 2} = RateLimitLeakyBucket.hit(key, leak_rate, capacity, 1)

      assert {:deny, _retry_after} =
               RateLimitLeakyBucket.hit(key, leak_rate, capacity, 1)
    end
  end

  describe "get" do
    test "get returns the count set for the given key and scale", %{key: key} do
      leak_rate = :timer.seconds(10)
      capacity = 10

      assert RateLimitLeakyBucket.get(key) == 0
      assert {:allow, 3} = RateLimitLeakyBucket.hit(key, leak_rate, capacity, 3)
      assert RateLimitLeakyBucket.get(key) == 3
    end
  end

  describe "non-string keys" do
    test "works with atom keys" do
      leak_rate = :timer.seconds(10)
      capacity = 10

      assert {:allow, 1} = RateLimitLeakyBucket.hit(:atom_key, leak_rate, capacity)
      assert RateLimitLeakyBucket.get(:atom_key) == 1
    end

    test "works with tuple keys" do
      leak_rate = :timer.seconds(10)
      capacity = 10
      tuple_key = {:user, 123}

      assert {:allow, 1} = RateLimitLeakyBucket.hit(tuple_key, leak_rate, capacity)
      assert RateLimitLeakyBucket.get(tuple_key) == 1
    end

    test "works with integer keys" do
      leak_rate = :timer.seconds(10)
      capacity = 10

      assert {:allow, 1} = RateLimitLeakyBucket.hit(123, leak_rate, capacity)
      assert RateLimitLeakyBucket.get(123) == 1
    end
  end
end
