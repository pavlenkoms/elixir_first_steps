#Этот модуль должен реализовать механизмы CRUD для хранения данных.
#Если одного модуля будет мало,
#то допускается создание модулей с префиксом "Storage" в названии.

defmodule KVStore.Storage do
  use GenServer
  require Logger
  require Application

  def start_link(name) do
    GenServer.start_link(__MODULE__, [], name: name)
  end

  def start_link(name, dets_path, table_name) do
    GenServer.start_link(__MODULE__, [dets_path, table_name], name: name)
  end

  def stop(name) do
    GenServer.stop(name)
  end

  def create(key, value, ttl) when is_integer(ttl) do
    GenServer.call(__MODULE__, {:create, {key, value, ttl}})
  end
  def create(_, _, _ttl) do
    :bad_ttl
  end

  def update(key, value, ttl) when is_integer(ttl) do
    GenServer.call(__MODULE__, {:update, {key, value, ttl}})
  end
  def update(_, _, _ttl) do
    :bad_ttl
  end

  def read(key) do
    GenServer.call(__MODULE__, {:read, key})
  end

  def delete(key) do
    GenServer.call(__MODULE__, {:delete, key})
  end

  def clear() do
    GenServer.call(__MODULE__, {:clear})
  end

  def init([]) do
    init(['dets.dets', :kv_storage])
  end
  def init([dets_path, table_name]) do
    foldFun =
      fn({_k, _v, 0, _ts}, acc) ->
        # не меняем эти элементы
        acc
      ({k, _v, t, ts}, {to_del, to_refresh}) ->
        {megaSec2, sec2, microSec2} = :os.timestamp()
        {megaSec1, sec1, microSec1} = ts
        diff =
          (megaSec2 * 1000000 + sec2 * 1000 + div(microSec2, 1000)) -
          megaSec1 * 1000000 + sec1 * 1000 + div(microSec1, 1000)
        cond do
          diff >= t ->
            {[k | to_del], to_refresh}
          true ->
            {to_del, [{k, diff} | to_refresh]}
        end
      end

    {:ok, _} = :dets.open_file(table_name, [file: dets_path])
    {del, refresh} = :dets.foldl(foldFun, {[], []}, table_name)
    for k <- del, do: :dets.delete(table_name, k)

    refreshFun =
      fn({k, diff}, tst) ->
        make_timer(tst, diff, k)
      end

    timers = List.foldl(refresh, %{}, refreshFun)

    {:ok, %{:dets => table_name, :timers => timers}}
  end
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

  def handle_call({:create, {key, value, ttl} = cmd}, _from, state) do
    Logger.debug("create  #{inspect cmd}")
    dets = state[:dets]
    case :dets.member(dets, key) do
      false ->
        :dets.insert(dets, {key, value, ttl, :os.timestamp()})
        :dets.sync(dets)
        timers = make_timer(state[:timers], ttl, key)
        {:reply, :ok, %{state | :timers => timers}}
      true ->
        {:reply, :already_exist, state}
    end
  end

  def handle_call({:update, {key, value, ttl} = cmd}, _from, state) do
    Logger.debug("update  #{inspect cmd}")
    dets = state[:dets]
    case :dets.member(dets, key) do
      true ->
        :dets.insert(dets, {key, value, ttl, :os.timestamp()})
        timers = cancel_timer(state[:timers], key)
        timers = make_timer(timers, ttl, key)
        :dets.sync(dets)
        {:reply, :ok, %{state | :timers => timers}}
      false ->
        {:reply, :does_not_exist, state}
    end
  end

  def handle_call({:read, key}, _from, state) do
    Logger.debug("read  #{inspect key}")
    dets = state[:dets]
    case :dets.member(dets, key) do
      true ->
        [{^key, value, _, _}] = :dets.lookup(dets, key)
        {:reply, {:value, value}, state}
      false ->
        {:reply, :does_not_exist, state}
      end
  end

  def handle_call({:delete, key}, _from, state) do
    Logger.debug("delete  #{inspect key}")
    dets = state[:dets]
    case :dets.member(dets, key) do
      true ->
        timers = cancel_timer(state[:timers], key)
        :dets.delete(dets, key)
        :dets.sync(dets)
        {:reply, :ok, %{state | :timers => timers}}
      false ->
        {:reply, :does_not_exist, state}
    end
  end

  def handle_call({:clear}, _, state) do
    :dets.delete_all_objects(state[:dets])
    {:reply, :ok, state}
  end

  def handle_call(call, _, state) do
    Logger.warn("unknown request #{inspect call}")
    {:noreply, state}
  end
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

  def handle_cast(_, state) do
    {:noreply, state}
  end
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

  def handle_info({:time_is_up, key, msg_ref}, state) do
    Logger.debug("time is up  #{inspect key}, #{inspect msg_ref}")
    timers = state[:timers]
    case timers[key] do
      {_, ^msg_ref} ->
        {_, _, state} = handle_call({:delete, key}, :undefined, state)
        {:noreply, state}
      _ ->
        Logger.warn("rotten timer for #{inspect key}, #{inspect msg_ref}")
        {:noreply, state}
    end
  end

  def handle_info(_info, state) do
    {:noreply, state}
  end

#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------
  def terminate(_, state) do
    :dets.close(state[:dets])
    :ok
  end
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

  def cancel_timer(timers, key) do
    case timers[key] do
      {ref, msg_ref} ->
        Logger.debug("cancel timer #{inspect key}, #{inspect msg_ref}")
        :timer.cancel(ref)
        Map.delete(timers, key)
      _ -> timers
    end
  end

  def make_timer(timers, 0, _) do
    timers
  end
  def make_timer(timers, ttl, key) when is_integer(ttl) do
    msg_ref = Kernel.make_ref()
    {:ok, ref} = :timer.send_after(ttl, {:time_is_up, key, msg_ref})
    Logger.debug("make #{inspect key}, #{inspect msg_ref}")
    Map.put(timers, key, {ref, msg_ref})
  end

  def clear_dets() do
    :dets.close(:kv_storage)
  end
end
