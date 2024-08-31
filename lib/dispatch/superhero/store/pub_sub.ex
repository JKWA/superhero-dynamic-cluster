defmodule Dispatch.Store.PubSub do
  use GenServer
  alias Phoenix.PubSub
  alias Dispatch.Store.SuperheroStore

  require Logger

  def topic do
    "data_on_#{Node.self()}"
  end

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(state) do
    :mnesia.subscribe({:table, :superhero, :detailed})
    Logger.info("Subscribed to changes in the superhero table.")
    {:ok, state}
  end

  @impl true
  def handle_info(
        {:mnesia_table_event, {:write, :superhero, superhero_details, _op_extra, _tid_info}},
        state
      ) do
    Logger.info("Superhero updated or added: #{inspect(superhero_details)}")
    broadcast_latest_superheroes()
    {:noreply, state}
  end

  @impl true
  def handle_info(
        {:mnesia_table_event, {:delete, :superhero, superhero_details, _op_extra, _tid_info}},
        state
      ) do
    Logger.info("Superhero deleted: #{inspect(superhero_details)}")
    broadcast_latest_superheroes()
    {:noreply, state}
  end

  defp broadcast_latest_superheroes do
    case SuperheroStore.get_all_superheroes() do
      {:ok, superheroes} ->
        Logger.info("Broadcasting superhero updates: #{inspect(superheroes)}")

        PubSub.broadcast(
          Dispatch.PubSub,
          topic(),
          {:update_data, superheroes}
        )

      {:error, reason} ->
        Logger.error("Failed to retrieve superheroes: #{inspect(reason)}")
    end
  end
end
