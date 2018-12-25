defmodule HammerBackendMnesiaTest do
  use ExUnit.Case
  import Mock

  setup _context do
    :mnesia.create_schema([node()])
    Hammer.Backend.Mnesia.create_mnesia_table()
    {:ok, pid} = Hammer.Backend.Mnesia.start_link(expiry_ms: 60_000)
    {:ok, [pid: pid]}
  end

  test "count_hit, first", context do
    pid = context[:pid]
  end

  test "count_hit, first, with custom increment", context do
    pid = context[:pid]
  end

  test "count_hit, after", context do
    pid = context[:pid]
  end

  test "count_hit, after, with custom increment", context do
    pid = context[:pid]
  end

  test "count_hit, handles race condition", context do
    pid = context[:pid]
  end

  test "get_bucket", context do
    pid = context[:pid]
 end

  test "delete buckets", context do
    pid = context[:pid]
  end
end
