defmodule Hammer.Backend.Mnesia do
  @moduledoc """
  Documentation for Hammer.Backend.Redis
  """

  @type bucket_key :: {bucket :: integer, id :: String.t()}
  @type bucket_info ::
          {key :: bucket_key, count :: integer, created :: integer, updated :: integer}

  use GenServer
  @behaviour Hammer.Backend

  @default_table_name :__hammer_backend_mnesia

  ## Public API

  def create_mnesia_table do
    create_mnesia_table(@default_table_name)
  end

  def create_mnesia_table(table_name) do
    :mnesia.create_table(
      table_name,
      attributes: [:key, :bucket, :id, :count, :created, :updated]
    )
  end

  def start do
    start([])
  end

  def start(args) do
    GenServer.start(__MODULE__, args)
  end

  def start_link do
    start_link([])
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  def stop do
    GenServer.call(__MODULE__, :stop)
  end

  @doc """
  Record a hit in the bucket identified by `key`
  """
  @spec count_hit(
          pid :: pid(),
          key :: bucket_key,
          now :: integer
        ) ::
          {:ok, count :: integer}
          | {:error, reason :: any}
  def count_hit(pid, key, now) do
    GenServer.call(pid, {:count_hit, key, now, 1})
  end

  @doc """
  Record a hit in the bucket identified by `key`, with a custom increment
  """
  @spec count_hit(
          pid :: pid(),
          key :: bucket_key,
          now :: integer,
          increment :: integer
        ) ::
          {:ok, count :: integer}
          | {:error, reason :: any}
  def count_hit(pid, key, now, increment) do
    GenServer.call(pid, {:count_hit, key, now, increment})
  end

  @doc """
  Retrieve information about the bucket identified by `key`
  """
  @spec get_bucket(
          pid :: pid(),
          key :: bucket_key
        ) ::
          {:ok, info :: bucket_info}
          | {:ok, nil}
          | {:error, reason :: any}
  def get_bucket(pid, key) do
    GenServer.call(pid, {:get_bucket, key})
  end

  @doc """
  Delete all buckets associated with `id`.
  """
  @spec delete_buckets(
          pid :: pid(),
          id :: String.t()
        ) ::
          {:ok, count_deleted :: integer}
          | {:error, reason :: any}
  def delete_buckets(pid, id) do
    GenServer.call(pid, {:delete_buckets, id})
  end

  ## GenServer Callbacks

  def init(args) do
    {:ok, %{}}
  end

  def handle_call(:stop, _from, state) do
    {:stop, :normal, :ok, state}
  end

  def handle_call({:count_hit, key, now, increment}, _from, %{} = state) do
    result = 1
    {:reply, result, state}
  end

  def handle_call({:get_bucket, key}, _from, %{} = state) do
    result = 1
    {:reply, result, state}
  end

  def handle_call({:delete_buckets, id}, _from, %{} = state) do
    result = 1
    {:reply, result, state}
  end
end
