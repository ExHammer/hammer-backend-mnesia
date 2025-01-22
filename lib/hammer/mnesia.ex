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

  The Mnesia backend supports the following algorithms:
    - `:fix_window` - Fixed window rate limiting (default)
      Simple counting within fixed time windows. See [Hammer.Mnesia.FixWindow](Hammer.Mnesia.FixWindow.html) for more details.

    - `:leaky_bucket` - Leaky bucket rate limiting
      Smooth rate limiting with a fixed rate of tokens. See [Hammer.Mnesia.LeakyBucket](Hammer.Mnesia.LeakyBucket.html) for more details.

    - `:token_bucket` - Token bucket rate limiting
      Flexible rate limiting with bursting capability. See [Hammer.Mnesia.TokenBucket](Hammer.Mnesia.TokenBucket.html) for more details.
  """

  use GenServer

  @type mnesia_option :: {:table, atom()}
  @type mnesia_options :: [mnesia_option()]

  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defmacro __before_compile__(%{module: module} = _env) do
    hammer_opts = Module.get_attribute(module, :hammer_opts)
    table = Keyword.get(hammer_opts, :table, module)

    algorithm =
      case Keyword.get(hammer_opts, :algorithm) do
        nil ->
          Hammer.Mnesia.FixWindow

        :fix_window ->
          Hammer.Mnesia.FixWindow

        :leaky_bucket ->
          Hammer.Mnesia.LeakyBucket

        :token_bucket ->
          Hammer.Mnesia.TokenBucket

        module ->
          case Code.ensure_compiled(module) do
            {:module, _} ->
              module

            {:error, _} ->
              raise ArgumentError, """
                Hammer requires a valid backend to be specified. Must be one of: :fix_window, :leaky_bucket, :token_bucket.
                If none is specified, :fix_window is used.

              Example:

                use Hammer, backend: Hammer.Mnesia, algorithm: Hammer.Mnesia.FixWindow
              """
          end
      end

    Code.ensure_loaded!(algorithm)

    quote do
      @table unquote(table)
      @algorithm unquote(algorithm)

      def child_spec(opts) do
        %{
          id: __MODULE__,
          start: {__MODULE__, :start_link, [opts]},
          type: :worker
        }
      end

      def start_link(opts) do
        opts = Keyword.put(opts, :table, @table)
        opts = Keyword.put_new(opts, :algorithm, @algorithm)

        Hammer.Mnesia.start_link(opts)
      end

      def hit(key, scale, limit, increment \\ 1) do
        @algorithm.hit(@table, key, scale, limit, increment)
      end

      if function_exported?(@algorithm, :inc, 4) do
        def inc(key, scale, increment \\ 1) do
          @algorithm.inc(@table, key, scale, increment)
        end
      end

      if function_exported?(@algorithm, :set, 4) do
        def set(key, scale, count) do
          @algorithm.set(@table, key, scale, count)
        end
      end

      if function_exported?(@algorithm, :get, 2) do
        def get(key) do
          @algorithm.get(@table, key)
        end
      end

      if function_exported?(@algorithm, :get, 3) do
        def get(key, scale) do
          @algorithm.get(@table, key, scale)
        end
      end
    end
  end

  @doc """
  Starts the process that creates and cleans the ETS table.

  Accepts the following options:
    - `:clean_period` for how often to perform garbage collection
    - optional mnesia options from `:mnesia.create_table/2`
    - `:key_older_than` - How old a key can be before it is removed from the table (in milliseconds). Defaults to 10 minutes.
    - `:algorithm` - The rate limiting algorithm to use. Can be `:fixed_window`, `:token_bucket`, or `:leaky_bucket`. Defaults to `:fixed_window`.
    - optional `:debug`, `:spawn_opts`, and `:hibernate_after` `GenServer.options()`
  """
  @spec start_link(Hammer.Mnesia.mnesia_options()) ::
          {:ok, pid()} | :ignore | {:error, term()}
  def start_link(opts) do
    {gen_opts, opts} = Keyword.split(opts, [:debug, :spawn_opt, :hibernate_after])
    GenServer.start_link(__MODULE__, opts, gen_opts)
  end

  @compile inline: [now: 0]
  def now do
    System.system_time(:millisecond)
  end

  @impl GenServer
  def init(opts) do
    {:ok, opts, {:continue, :init}}
  end

  # TODO listen for cluster changes
  # TODO attempt unsplit
  @impl GenServer
  def handle_continue(:init, opts) do
    {clean_period, opts} = Keyword.pop!(opts, :clean_period)
    {algorithm, opts} = Keyword.pop!(opts, :algorithm)
    {key_older_than, opts} = Keyword.pop(opts, :key_older_than, :timer.minutes(10))
    {table, mnesia_opts} = Keyword.pop!(opts, :table)
    mnesia_opts = Keyword.merge(mnesia_opts, algorithm.mnesia_opts())

    case :mnesia.create_table(table, mnesia_opts) do
      {:atomic, :ok} -> :ok
      {:aborted, {:already_exists, _}} -> :ok
      {:aborted, reason} -> :erlang.error(reason)
    end

    schedule(clean_period)

    {:noreply,
     %{
       table: table,
       algorithm: algorithm,
       clean_period: clean_period,
       key_older_than: key_older_than
     }}
  end

  @impl GenServer
  def handle_info(:clean, state) do
    algorithm = state.algorithm
    algorithm.clean(state)
    schedule(state.clean_period)
    {:noreply, state}
  end

  defp schedule(clean_period) do
    Process.send_after(self(), :clean, clean_period)
  end
end
