defmodule Dispatch.SuperheroServer do
  use GenServer
  require Logger

  alias Dispatch.{SuperheroRegistry, Superhero, SuperheroApi, Store}
  alias Horde.Registry
  alias Store.SuperheroStore

  @polling_interval 4000
  @max_health 100
  @default_fights 0

  def start_link(id) do
    GenServer.start_link(__MODULE__, id, name: via_tuple(id))
  end

  @impl true
  def init(id) do
    Process.flag(:trap_exit, true)

    Logger.info("Initializing superhero server for #{id}")
    send(self(), :init_superhero)
    schedule_next_action()

    {:ok, %Superhero{id: id}}
  end

  @impl true
  def handle_info(:init_superhero, superhero) do
    superhero =
      case SuperheroStore.get_superhero(superhero.id) do
        {:ok, existing_superhero} ->
          Logger.info(
            "Superhero #{superhero.id} already exists in Mnesia. Using existing superhero."
          )

          existing_superhero |> Map.put(:node, node())

        {:error, :not_found} ->
          generate_new_superhero(superhero)

        {:error, reason} ->
          Logger.error(
            "Failed to retrieve superhero #{superhero.id} from Mnesia: #{inspect(reason)}"
          )

          superhero
      end

    send(self(), {:update_superhero, superhero})
    {:noreply, superhero}
  end

  @impl true
  def handle_info(:decide_action, superhero) do
    superhero =
      case random_action() do
        :fighting ->
          GenServer.cast(self(), :fighting_crime)
          Map.put(superhero, :is_patrolling, true)

        :resting ->
          GenServer.cast(self(), :resting)
          Map.put(superhero, :is_patrolling, false)
      end

    schedule_next_action()
    {:noreply, superhero}
  end

  @impl true
  def handle_info({:update_superhero, superhero}, _state) do
    case SuperheroStore.upsert_superhero(superhero) do
      {:ok, saved_superhero} ->
        Logger.info("Superhero #{saved_superhero.id} added to Mnesia.")
        {:noreply, saved_superhero}

      {:error, reason} ->
        Logger.error("Failed to add superhero #{superhero.id} to Mnesia: #{inspect(reason)}")
        {:noreply, superhero}
    end
  end

  @impl true
  def handle_cast(:resting, superhero) do
    health_gain = :rand.uniform(40)
    new_health = min(superhero.health + health_gain, @max_health)
    updated_superhero = Map.put(superhero, :health, new_health)

    Logger.info(
      "#{superhero.name} is resting and has regained #{health_gain} health points, new health: #{new_health}."
    )

    send(self(), {:update_superhero, updated_superhero})
    {:noreply, updated_superhero}
  end

  @impl true
  def handle_cast(:fighting_crime, superhero) do
    case :rand.uniform(2) do
      1 -> {:noreply, handle_win(superhero)}
      2 -> {:noreply, handle_loss(superhero)}
    end
  end

  @impl true
  def terminate(reason, superhero) do
    Logger.info(
      "Terminating superhero server for #{superhero.name} with reason: #{inspect(reason)}"
    )

    :ok
  end

  defp generate_new_superhero(superhero) do
    new_superhero =
      superhero
      |> Map.put(:node, node())
      |> Map.put(:name, "#{Faker.Superhero.prefix()} #{Faker.Superhero.name()}")

    send(self(), {:update_superhero, new_superhero})
    new_superhero
  end

  defp handle_win(superhero) do
    updated_superhero = Map.update(superhero, :fights_won, &(&1 + 1), @default_fights)
    Logger.info("#{superhero.name} won a fight, total wins: #{updated_superhero.fights_won}")
    send(self(), {:update_superhero, updated_superhero})
    updated_superhero
  end

  defp handle_loss(superhero) do
    health_loss = :rand.uniform(40)
    updated_superhero = update_superhero_losses(superhero, health_loss)

    Logger.info(
      "#{superhero.name} lost a fight, lost #{health_loss} health, remaining health: #{updated_superhero.health}"
    )

    if updated_superhero.health <= 0 do
      handle_critical_health(updated_superhero)
    else
      send(self(), {:update_superhero, updated_superhero})
      updated_superhero
    end
  end

  defp handle_critical_health(superhero) do
    Logger.warning("#{superhero.name} has health <= 0, terminating.")
    SuperheroStore.delete_superhero(superhero.id)
    SuperheroApi.stop(superhero.id)
    {:noreply, superhero}
  end

  defp update_superhero_losses(superhero, health_loss) do
    superhero
    |> Map.update(:health, @max_health, &(&1 - health_loss))
    |> Map.update(:fights_lost, @default_fights, &(&1 + 1))
  end

  defp random_action do
    if :rand.uniform(4) == 1, do: :resting, else: :fighting
  end

  defp schedule_next_action do
    Process.send_after(self(), :decide_action, @polling_interval)
  end

  def via_tuple(id), do: {:via, Registry, {SuperheroRegistry, id}}
end
