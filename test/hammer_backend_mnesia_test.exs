defmodule HammerBackendMnesiaTest do
  use ExUnit.Case

  alias Hammer.Backend
  alias Hammer.Utils

  :mnesia.create_schema([node()])
  :mnesia.start()

  Backend.Mnesia.create_mnesia_table()

  setup _context do
    opts = [expiry_ms: 100, cleanup_interval_ms: 50]
    {:ok, pid} = Backend.Mnesia.start_link(opts)

    {:ok, Keyword.put(opts, :pid, pid)}
  end

  test "count_hit", context do
    pid = context[:pid]
    {stamp, key} = Utils.stamp_key("one", 200_000)
    assert {:ok, 1} = Backend.Mnesia.count_hit(pid, key, stamp)
    assert {:ok, 2} = Backend.Mnesia.count_hit(pid, key, stamp)
    assert {:ok, 3} = Backend.Mnesia.count_hit(pid, key, stamp)
    assert {:ok, 8} = Backend.Mnesia.count_hit(pid, key, stamp, 5)
  end

  test "get_bucket", context do
    pid = context[:pid]
    {stamp, key} = Utils.stamp_key("two", 200_000)
    # With no hits
    assert {:ok, nil} = Backend.Mnesia.get_bucket(pid, key)
    # With one hit
    assert {:ok, 1} = Backend.Mnesia.count_hit(pid, key, stamp)
    assert {:ok, {{_, "two"}, 1, _, _}} = Backend.Mnesia.get_bucket(pid, key)
    # With two hits
    assert {:ok, 2} = Backend.Mnesia.count_hit(pid, key, stamp)
    assert {:ok, {{_, "two"}, 2, _, _}} = Backend.Mnesia.get_bucket(pid, key)
    # With another hit with custom increment
    assert {:ok, 6} = Backend.Mnesia.count_hit(pid, key, stamp, 4)
    assert {:ok, {{_, "two"}, 6, _, _}} = Backend.Mnesia.get_bucket(pid, key)
  end

  test "delete_buckets", context do
    pid = context[:pid]
    {stamp, key} = Utils.stamp_key("three", 200_000)
    # With no hits
    assert {:ok, 0} = Backend.Mnesia.delete_buckets(pid, "three")
    # With three hits in same bucket
    assert {:ok, 1} = Backend.Mnesia.count_hit(pid, key, stamp)
    assert {:ok, 2} = Backend.Mnesia.count_hit(pid, key, stamp)
    assert {:ok, 3} = Backend.Mnesia.count_hit(pid, key, stamp)
    assert {:ok, 1} = Backend.Mnesia.delete_buckets(pid, "three")
  end

  test "timeout pruning", context do
    pid = context[:pid]
    expiry_ms = context[:expiry_ms]
    {stamp, key} = Utils.stamp_key("four", 200_000)
    assert {:ok, 1} = Backend.Mnesia.count_hit(pid, key, stamp)
    assert {:ok, {{_, "four"}, 1, _, _}} = Hammer.Backend.Mnesia.get_bucket(pid, key)
    :timer.sleep(expiry_ms * 2)
    assert {:ok, nil} = Backend.Mnesia.get_bucket(pid, key)
  end
end
