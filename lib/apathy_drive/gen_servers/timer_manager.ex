defmodule TimerManager do
  use Systems.Reload
  use GenServer

  # Public API
  def call_after(timer_manager, {name, time, function}) do
    ref = :erlang.start_timer(time, timer_manager, {name, function})
    GenServer.cast(timer_manager, {:add_timer, name, ref})
    ref
  end

  def call_every(timer_manager, {name, time, function}) do
    ref = :erlang.start_timer(time, timer_manager, {name, time, function})
    GenServer.cast(timer_manager, {:add_timer, name, ref})
    ref
  end

  def timers(timer_manager) do
    GenServer.call(timer_manager, :get_timers)
  end

  def time_remaining(timer_manager, name) do
    GenServer.call(timer_manager, {:time_remaining, name})
  end

  def cancel(timer_manager, name) do
    GenServer.cast(timer_manager, {:cancel, name})
  end

  defp execute_function(function) do
    try do
      function.()
    catch
      kind, error ->
        IO.puts Exception.format(kind, error)
        # {fun, arity} = env.function
        # IO.puts """
        # ** BlockTimer apply error, originating from:
        #      #{env.file}:#{env.line} in #{fun}/#{arity}
        #    error:
        #      #{Exception.format(kind, error)}
        # """
    end
  end

  # GenServer API
  def start do
    GenServer.start(__MODULE__, HashDict.new)
  end

  def init(value) do
    {:ok, value}
  end

  def handle_cast({:add_timer, name, ref}, refs) do
    {:noreply, HashDict.put(refs, name, ref) }
  end

  def handle_cast({:cancel, name}, refs) do
    if ref = HashDict.get(refs, name) do
      :erlang.cancel_timer(ref)
    end
    {:noreply, HashDict.delete(refs, name) }
  end

  def handle_call(:get_timers, _from, refs) do
    {:reply, HashDict.keys(refs), refs}
  end

  def handle_call({:time_remaining, name}, _from, refs) do
    if ref = HashDict.get(refs, name) do
      {:reply, :erlang.read_timer(ref), refs}
    else
      {:reply, nil, refs}
    end
  end

  def handle_info({:timeout, ref, {name, time, function}}, refs) do
    new_ref = :erlang.start_timer(time, self, {name, time, function})

    execute_function(function)

    {:noreply, HashDict.put(refs, name, new_ref)}
  end

  def handle_info({:timeout, ref, {name, function}}, refs) do
    execute_function(function)
    {:noreply, HashDict.delete(refs, name)}
  end

  def handle_info(info, refs) do
    IO.puts "Unexpected TimerManger info: #{inspect(info)}"
    {:noreply, refs}
  end

end