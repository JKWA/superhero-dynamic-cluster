defmodule Dispatch.SuperheroApi do
  require Logger

  alias Dispatch.{
    SuperheroRegistry,
    SuperheroServer,
    SuperheroSupervisor,
    SuperheroRegistryHandler
  }

  alias Horde.{DynamicSupervisor, Registry}
  require Logger

  def start(name) do
    child_spec = %{
      id: name,
      start: {SuperheroServer, :start_link, [name]}
    }

    case DynamicSupervisor.start_child(SuperheroSupervisor, child_spec) do
      {:ok, pid} ->
        Logger.info("Superhero created successfully: #{name} with PID #{inspect(pid)}")
        {:ok, pid}

      {:error, reason} ->
        Logger.error("Failed to create superhero: #{name} due to #{inspect(reason)}")
        {:error, reason}
    end
  end

  def stop(name) do
    case SuperheroRegistryHandler.get_pid_for_superhero(name) do
      nil ->
        {:error, :not_found}

      pid ->
        :ok = DynamicSupervisor.terminate_child(SuperheroSupervisor, pid)
        :ok = Registry.unregister(SuperheroRegistry, name)

        {:ok, :terminated}
    end
  end

  def get_details(name) do
    GenServer.call(SuperheroServer.via_tuple(name), :get_details)
  end

  def get_all_superheroes_with_details do
    SuperheroRegistryHandler.get_all_superheroes()
    |> Enum.map(fn name ->
      get_details(name)
      |> Map.put(:node, SuperheroRegistryHandler.get_node_for_superhero(name))
    end)
  end
end