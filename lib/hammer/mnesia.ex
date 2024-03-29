defmodule Hammer.Mnesia do
  @moduledoc """
  This backend uses the `:mnesia`.

      defmodule MyApp.RateLimit do
        # the default table is the current's module name
        use Hammer, backend: Hammer.Mnesia, table: __MODULE__
      end

      # attempts to create a distributed in-memory table and run the clean up every 10 minutes
      MyApp.RateLimit.start_link(clean_period: :timer.minutes(10))

      {:allow, _count} = MyApp.RateLimit.hit(key, scale, limit)

  """

  defmacro __before_compile__(%{module: module} = _env) do
    hammer_opts = Module.get_attribute(module, :hammer_opts)
    table = Keyword.get(hammer_opts, :table, module)

    quote do
      @table unquote(table)

      def child_spec(opts) do
        %{
          id: __MODULE__,
          start: {__MODULE__, :start_link, [opts]},
          type: :worker
        }
      end

      def start_link(opts) do
        opts = Keyword.put(opts, :table, @table)
        Hammer.Mnesia.start_link(opts)
      end

      def hit(key, scale, limit, increment \\ 1) do
        Hammer.Mnesia.hit(@table, key, scale, limit, increment)
      end

      def inc(key, scale, increment \\ 1) do
        Hammer.Mnesia.inc(@table, key, scale, increment)
      end

      def set(key, scale, count) do
        Hammer.Mnesia.set(@table, key, scale, count)
      end

      def get(key, scale) do
        Hammer.Mnesia.get(@table, key, scale)
      end
    end
  end

  use GenServer

  @doc """
  Starts the process that creates and cleans the ETS table.

  Accepts the following options:
    - `:clean_period` for how often to perform garbage collection
    - optional mnesia options from `:mnesia.create_table/2`
    - optional `:debug`, `:spawn_opts`, and `:hibernate_after` `GenServer.options()`
  """
  def start_link(opts) do
    {gen_opts, opts} = Keyword.split(opts, [:debug, :spawn_opt, :hibernate_after])
    GenServer.start_link(__MODULE__, opts, gen_opts)
  end

  @doc false
  def hit(table, key, scale, limit, increment) do
    now = now()
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
  def inc(table, key, scale, increment) do
    :mnesia.dirty_update_counter(table, full_key(key, scale), increment)
  end

  @doc false
  def set(table, key, scale, count) do
    full_key = full_key(key, scale)
    current_count = :mnesia.dirty_update_counter(table, full_key, 0)
    :mnesia.dirty_update_counter(table, full_key, count - current_count)
  end

  @doc false
  def get(table, key, scale) do
    :mnesia.dirty_update_counter(table, full_key(key, scale), 0)
  end

  @compile inline: [full_key: 2]
  defp full_key(key, scale) do
    full_key(key, scale, now())
  end

  @compile inline: [full_key: 3]
  defp full_key(key, scale, now) do
    window = div(now, scale)
    expires_at = (window + 1) * scale
    {key, window, expires_at}
  end

  @compile inline: [now: 0]
  defp now do
    System.system_time(:millisecond)
  end

  @impl GenServer
  def init(opts) do
    {:ok, opts, {:continue, :init}}
  end

  # TODO retry and log errors
  # TODO listen for cluster changes
  # TODO attempt unsplit
  @impl true
  def handle_continue(:init, opts) do
    {clean_period, opts} = Keyword.pop!(opts, :clean_period)
    {table, mnesia_opts} = Keyword.pop!(opts, :table)

    mnesia_opts = Keyword.merge(mnesia_opts, type: :set, attributes: [:key, :count])

    case :mnesia.create_table(table, mnesia_opts) do
      {:atomic, :ok} -> :ok
      {:aborted, {:already_exists, _}} -> :ok
      {:aborted, reason} -> :erlang.error(reason)
    end

    schedule(clean_period)
    {:noreply, %{table: table, clean_period: clean_period}}
  end

  @impl GenServer
  def handle_info(:clean, state) do
    clean(state.table)
    schedule(state.clean_period)
    {:noreply, state}
  end

  defp schedule(clean_period) do
    Process.send_after(self(), :clean, clean_period)
  end

  defp clean(table) do
    # generated with `:ets.fun2ms fn {_, {k, w, e}, _} when e < 123 -> {k, w, e} end`
    ms = [
      {{:_, {:"$1", :"$2", :"$3"}, :_}, [{:<, :"$3", {:const, now()}}], [{{:"$1", :"$2", :"$3"}}]}
    ]

    expired_keys = :mnesia.dirty_select(table, ms)
    Enum.each(expired_keys, fn key -> :mnesia.dirty_delete(table, key) end)
  end
end
