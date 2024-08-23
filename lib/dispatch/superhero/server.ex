defmodule Dispatch.SuperheroServer do
  use GenServer
  require Logger

  alias Dispatch.{SuperheroRegistry, Superhero, SuperheroApi}
  alias Horde.Registry

  @polling_interval 4000

  def start_link(name) do
    GenServer.start_link(__MODULE__, name, name: via_tuple(name))
  end

  @impl true
  def init(name) do
    Process.flag(:trap_exit, true)
    Logger.info("Initializing superhero server for #{name}")

    send(self(), :init_superhero)
    Process.send_after(self(), :decide_action, @polling_interval)

    {:ok, %Superhero{name: name}}
  end

  @impl true
  def handle_call(:get_details, _from, superhero) do
    {:reply, superhero, superhero}
  end

  @impl true
  def handle_cast(:resting, superhero) do
    health_gain = :rand.uniform(40)
    new_health = min(superhero.health + health_gain, 100)
    new_superhero = Map.put(superhero, :health, new_health)

    Logger.info(
      "#{superhero.name} is resting and has regained #{health_gain} health points, new health: #{new_health}."
    )

    {:noreply, new_superhero}
  end

  @impl true
  def handle_cast(:fighting_crime, superhero) do
    if :rand.uniform(2) == 1 do
      new_superhero = Map.update!(superhero, :fights_won, &(&1 + 1))
      Logger.info("#{superhero.name} won a fight, total wins: #{new_superhero.fights_won}")
      {:noreply, new_superhero}
    else
      health_loss = :rand.uniform(40)
      new_health = superhero.health - health_loss
      new_superhero = Map.update!(superhero, :health, &(&1 - health_loss))
      new_superhero = Map.update!(new_superhero, :fights_lost, &(&1 + 1))

      Logger.info(
        "#{superhero.name} lost a fight, lost #{health_loss} health, remaining health: #{new_health}"
      )

      if new_health <= 0 do
        Logger.warning("#{superhero.name} has health <= 0, terminating.")
        SuperheroApi.stop(superhero.name)
      end

      {:noreply, new_superhero}
    end
  end

  @impl true
  def handle_info(:init_superhero, superhero) do
    updated_superhero = Superhero.get_state(superhero.name)
    {:noreply, updated_superhero}
  end

  @impl true
  def handle_info(:decide_action, superhero) do
    new_superhero =
      case random_action() do
        :fighting ->
          GenServer.cast(self(), :fighting_crime)
          Map.put(superhero, :is_patrolling, true)

        :resting ->
          GenServer.cast(self(), :resting)
          Map.put(superhero, :is_patrolling, false)
      end

    Process.send_after(self(), :decide_action, @polling_interval)
    {:noreply, new_superhero}
  end

  @impl true
  def terminate(reason, superhero) do
    Logger.info(
      "Terminating superhero server for #{superhero.name} with reason: #{inspect(reason)}"
    )

    :ok
  end

  defp random_action do
    if :rand.uniform(4) == 1 do
      :resting
    else
      :fighting
    end
  end

  def via_tuple(id), do: {:via, Registry, {SuperheroRegistry, id}}
end
