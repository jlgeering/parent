defmodule Parent.Supervisor do
  use Parent.GenServer

  @type option ::
          Parent.GenServer.option()
          | {:children, [Parent.child_spec() | module | {module, term}]}

  @spec start_link([option]) :: GenServer.on_start()
  def start_link(options) do
    {children, options} = Keyword.pop(options, :children, [])
    Parent.GenServer.start_link(__MODULE__, children, options)
  end

  @spec child_pid(GenServer.server(), Parent.child_id()) :: {:ok, pid} | :error
  def child_pid(supervisor, child_id),
    do: GenServer.call(supervisor, {:child_pid, child_id})

  @spec child_meta(GenServer.server(), Parent.child_id()) :: {:ok, Parent.child_meta()} | :error
  def child_meta(supervisor, child_id),
    do: GenServer.call(supervisor, {:child_meta, child_id})

  @spec start_child(GenServer.server(), Parent.child_spec() | module | {module, term}) ::
          Supervisor.on_start_child()
  def start_child(supervisor, child_spec),
    do: GenServer.call(supervisor, {:start_child, child_spec}, :infinity)

  @spec shutdown_child(GenServer.server(), Parent.child_id()) ::
          {:ok, Parent.on_shutdown_child()} | {:error, :unknown_child}
  def shutdown_child(supervisor, child_id),
    do: GenServer.call(supervisor, {:shutdown_child, child_id})

  @spec restart_child(GenServer.server(), Parent.child_id()) :: :ok | {:error, :unknown_child}
  def restart_child(supervisor, child_id),
    do: GenServer.call(supervisor, {:restart_child, child_id})

  @spec shutdown_all(GenServer.server()) :: :ok
  def shutdown_all(supervisor),
    do: GenServer.call(supervisor, :shutdown_all)

  @spec return_children(GenServer.server(), Parent.return_info()) :: :ok
  def return_children(supervisor, return_info),
    do: GenServer.call(supervisor, {:return_children, return_info})

  @spec update_child_meta(
          GenServer.server(),
          Parent.child_id(),
          (Parent.child_meta() -> Parent.child_meta())
        ) :: :ok | :error
  def update_child_meta(supervisor, child_id, updater),
    do: GenServer.call(supervisor, {:update_child_meta, child_id, updater})

  @impl GenServer
  def init(children) do
    Parent.start_all_children!(children)
    {:ok, nil}
  end

  @impl GenServer
  def handle_call({:child_pid, child_id}, _call, state),
    do: {:reply, Parent.child_pid(child_id), state}

  def handle_call({:child_meta, child_id}, _call, state),
    do: {:reply, Parent.child_meta(child_id), state}

  def handle_call({:start_child, child_spec}, _call, state),
    do: {:reply, Parent.start_child(child_spec), state}

  def handle_call({:shutdown_child, child_id}, _call, state) do
    response =
      if Parent.child?(child_id),
        do: {:ok, Parent.shutdown_child(child_id)},
        else: {:error, :unknown_child}

    {:reply, response, state}
  end

  def handle_call({:restart_child, child_id}, _call, state) do
    response =
      if Parent.child?(child_id),
        do: Parent.restart_child(child_id),
        else: {:error, :unknown_child}

    {:reply, response, state}
  end

  def handle_call(:shutdown_all, _call, state),
    do: {:reply, Parent.shutdown_all(), state}

  def handle_call({:return_children, return_info}, _call, state),
    do: {:reply, Parent.return_children(return_info), state}

  def handle_call({:update_child_meta, child_id, updater}, _call, state),
    do: {:reply, Parent.update_child_meta(child_id, updater), state}

  @spec child_spec([option]) :: Parent.child_spec()
end
