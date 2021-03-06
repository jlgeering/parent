defmodule Parent.Client do
  @moduledoc """
  Functions for interacting with parent's children from other processes.

  All of these functions issue a call to the parent process. Therefore, they can't be used from
  inside the parent process. Use functions from the `Parent` module instead to interact with the
  children from within the process.

  Likewise these functions can't be invoked inside the child process during its initialization.
  Defer interacting with the parent to `c:GenServer.handle_continue/2`, or if you're using another
  behaviour which doesn't support such callback, send yourself a message to safely do the post-init
  interaction with the parent.

  If parent is configured with the `registry?: true` option, some query functions, such as
  `child_pid/2` will perform an ETS lookup instead of issuing a call, so the caveats above won't
  apply.
  """
  alias Parent.Registry

  @doc """
  Client interface to `Parent.children/0`.

  If the parent is a registry, the result will be obtained from the ETS table.
  """
  @spec children(GenServer.server()) :: [Parent.child()]
  def children(parent) do
    case Registry.table(parent) do
      {:ok, table} -> Registry.children(table)
      :error -> call(parent, :children)
    end
  end

  @doc """
  Client interface to `Parent.child_pid/1`.

  If the parent is a registry, the result will be obtained from the ETS table.
  """
  @spec child_pid(GenServer.server(), Parent.child_id()) :: {:ok, pid} | :error
  def child_pid(parent, child_id) do
    case Registry.table(parent) do
      {:ok, table} -> Registry.child_pid(table, child_id)
      :error -> call(parent, :child_pid, [child_id])
    end
  end

  @doc """
  Client interface to `Parent.child_meta/1`.

  If the parent is a registry, the result will be obtained from the ETS table.
  """
  @spec child_meta(GenServer.server(), Parent.child_ref()) :: {:ok, Parent.child_meta()} | :error
  def child_meta(parent, child_ref) do
    case Registry.table(parent) do
      {:ok, table} -> Registry.child_meta(table, child_ref)
      :error -> call(parent, :child_meta, [child_ref])
    end
  end

  @doc "Client interface to `Parent.start_child/2`."
  @spec start_child(GenServer.server(), Parent.start_spec(), Keyword.t()) ::
          Parent.on_start_child()
  def start_child(parent, child_spec, overrides \\ []),
    do: call(parent, :start_child, [child_spec, overrides], :infinity)

  @doc "Client interface to `Parent.shutdown_child/1`."
  @spec shutdown_child(GenServer.server(), Parent.child_ref()) ::
          {:ok, Parent.stopped_children()} | :error
  def shutdown_child(parent, child_ref), do: call(parent, :shutdown_child, [child_ref], :infinity)

  @doc "Client interface to `Parent.restart_child/1`."
  @spec restart_child(GenServer.server(), Parent.child_ref()) :: :ok | :error
  def restart_child(parent, child_ref),
    do: call(parent, :restart_child, [child_ref], :infinity)

  @doc "Client interface to `Parent.shutdown_all/1`."
  @spec shutdown_all(GenServer.server(), any) :: Parent.stopped_children()
  def shutdown_all(server, reason \\ :shutdown),
    do: call(server, :shutdown_all, [reason], :infinity)

  @doc "Client interface to `Parent.return_children/1`."
  @spec return_children(GenServer.server(), Parent.stopped_children()) :: :ok
  def return_children(parent, stopped_children),
    do: call(parent, :return_children, [stopped_children], :infinity)

  @doc "Client interface to `Parent.update_child_meta/2`."
  @spec update_child_meta(
          GenServer.server(),
          Parent.child_id(),
          (Parent.child_meta() -> Parent.child_meta())
        ) :: :ok | :error
  def update_child_meta(parent, child_ref, updater),
    do: call(parent, :update_child_meta, [child_ref, updater], :infinity)

  @doc false
  def whereis_name({parent, child_id}) do
    case child_pid(parent, child_id) do
      {:ok, pid} -> pid
      :error -> :undefined
    end
  end

  defp call(server, function, args \\ [], timeout \\ 5000)
       when (is_integer(timeout) and timeout >= 0) or timeout == :infinity do
    # This is the custom implementation of a call. We're not using standard GenServer calls to
    # ensure that this call won't end up in some custom behaviour's handle_call.
    request = {__MODULE__, function, args}

    case GenServer.whereis(server) do
      nil ->
        exit({:noproc, {__MODULE__, :call, [server, request, timeout]}})

      pid when pid == self() ->
        exit({:calling_self, {__MODULE__, :call, [server, request, timeout]}})

      pid ->
        try do
          :gen.call(pid, :"$parent_call", request, timeout)
        catch
          :exit, reason ->
            exit({reason, {__MODULE__, :call, [server, request, timeout]}})
        else
          {:ok, res} -> res
        end
    end
  end
end
