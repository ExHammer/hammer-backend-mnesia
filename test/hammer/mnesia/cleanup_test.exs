defmodule Hammer.Mnesia.CleanUpTest do
  use ExUnit.Case, async: true

  @moduletag :slow

  defmodule RateLimit do
    use Hammer, backend: Hammer.Mnesia
  end

  setup do
    start_supervised!({RateLimit, clean_period: :timer.seconds(1)})
    on_exit(fn -> :mnesia.delete_table(RateLimit) end)
    :ok
  end

  test "cleans expired keys" do
    assert {:allow, 1} = RateLimit.hit("key", :timer.seconds(1), 1)
    assert {:deny, retry_after} = RateLimit.hit("key", :timer.seconds(1), 1)

    assert [{"key", _, _}] = :mnesia.dirty_all_keys(RateLimit)

    :timer.sleep(retry_after)
    :timer.sleep(_clean_period = :timer.seconds(1))

    assert :mnesia.dirty_all_keys(RateLimit) == []
  end
end
