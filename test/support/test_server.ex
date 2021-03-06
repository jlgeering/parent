defmodule Parent.TestServer do
  use Parent.GenServer

  def start_link({initializer, opts}),
    do: Parent.GenServer.start_link(__MODULE__, initializer, opts)

  def call(pid, fun), do: GenServer.call(pid, fun)

  def cast(pid, fun), do: GenServer.cast(pid, fun)

  def send(pid, fun), do: Kernel.send(pid, fun)

  @impl GenServer
  def init(initializer), do: {:ok, initializer.()}

  @impl GenServer
  def handle_call(fun, _from, state) do
    {response, state} = fun.(state)
    {:reply, response, state}
  end

  @impl GenServer
  def handle_cast(fun, state), do: {:noreply, fun.(state)}

  @impl GenServer
  def handle_info(fun, state) when is_function(fun), do: {:noreply, fun.(state)}
  def handle_info(_other, state), do: {:noreply, state}
end
