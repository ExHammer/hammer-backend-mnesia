defmodule Hammer.MnesiaTest do
  use ExUnit.Case, async: true

  defmodule RateLimit do
    use Hammer, backend: Hammer.Mnesia
  end

  setup do
    start_supervised!({RateLimit, clean_period: :timer.minutes(60)})

    # because of handle_continue in GenServer, need to wait for the table to be created
    Process.sleep(100)

    on_exit(fn -> :mnesia.delete_table(RateLimit) end)
    :ok
  end

  describe "hit" do
    test "returns {:allow, 1} tuple on first access" do
      key = "key"
      scale = :timer.seconds(10)
      limit = 10

      assert {:allow, 1} = RateLimit.hit(key, scale, limit)
    end

    test "returns {:allow, 4} tuple on in-limit checks" do
      key = "key"
      scale = :timer.minutes(10)
      limit = 10

      assert {:allow, 1} = RateLimit.hit(key, scale, limit)
      assert {:allow, 2} = RateLimit.hit(key, scale, limit)
      assert {:allow, 3} = RateLimit.hit(key, scale, limit)
      assert {:allow, 4} = RateLimit.hit(key, scale, limit)
    end

    test "returns expected tuples on mix of in-limit and out-of-limit checks" do
      key = "key"
      scale = :timer.minutes(10)
      limit = 2

      assert {:allow, 1} = RateLimit.hit(key, scale, limit)
      assert {:allow, 2} = RateLimit.hit(key, scale, limit)
      assert {:deny, _wait} = RateLimit.hit(key, scale, limit)
      assert {:deny, _wait} = RateLimit.hit(key, scale, limit)
    end

    test "returns expected tuples after waiting for the next window" do
      key = "key"
      scale = 100
      limit = 2

      assert {:allow, 1} = RateLimit.hit(key, scale, limit)
      assert {:allow, 2} = RateLimit.hit(key, scale, limit)
      assert {:deny, wait} = RateLimit.hit(key, scale, limit)

      :timer.sleep(wait)

      assert {:allow, 1} = RateLimit.hit(key, scale, limit)
      assert {:allow, 2} = RateLimit.hit(key, scale, limit)
      assert {:deny, _wait} = RateLimit.hit(key, scale, limit)
    end

    test "with custom increment" do
      key = "cost-key"
      scale = :timer.seconds(1)
      limit = 10

      assert {:allow, 4} = RateLimit.hit(key, scale, limit, 4)
      assert {:allow, 9} = RateLimit.hit(key, scale, limit, 5)
      assert {:deny, _wait} = RateLimit.hit(key, scale, limit, 3)
    end

    test "mixing default and custom increment" do
      key = "cost-key"
      scale = :timer.seconds(1)
      limit = 10

      assert {:allow, 3} = RateLimit.hit(key, scale, limit, 3)
      assert {:allow, 4} = RateLimit.hit(key, scale, limit)
      assert {:allow, 5} = RateLimit.hit(key, scale, limit)
      assert {:allow, 9} = RateLimit.hit(key, scale, limit, 4)
      assert {:allow, 10} = RateLimit.hit(key, scale, limit)
      assert {:deny, _wait} = RateLimit.hit(key, scale, limit, 2)
    end
  end

  describe "inc" do
    test "increments the count for the given key and scale" do
      key = "key"
      scale = :timer.seconds(10)

      assert RateLimit.get(key, scale) == 0

      assert RateLimit.inc(key, scale) == 1
      assert RateLimit.get(key, scale) == 1

      assert RateLimit.inc(key, scale) == 2
      assert RateLimit.get(key, scale) == 2

      assert RateLimit.inc(key, scale) == 3
      assert RateLimit.get(key, scale) == 3

      assert RateLimit.inc(key, scale) == 4
      assert RateLimit.get(key, scale) == 4
    end
  end

  describe "get/set" do
    test "get returns the count set for the given key and scale" do
      key = "key"
      scale = :timer.seconds(10)
      count = 10

      assert RateLimit.get(key, scale) == 0
      assert RateLimit.set(key, scale, count) == count
      assert RateLimit.get(key, scale) == count
    end
  end
end
