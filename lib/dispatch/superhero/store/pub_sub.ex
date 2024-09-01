defmodule Dispatch.Store.PubSub do
  use GenServer
  alias Dispatch.Superhero
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

    superhero =
      superhero_details
      |> Tuple.delete_at(0)
      |> SuperheroStore.convert_to_struct()

    PubSub.broadcast(
      Dispatch.PubSub,
      topic(),
      {:update_superhero, superhero}
    )

    {:noreply, state}
  end

  @impl true
  def handle_info(
        {:mnesia_table_event, {:delete, :superhero, superhero_details, _op_extra, _tid_info}},
        state
      ) do
    Logger.info("Superhero deleted: #{inspect(superhero_details)}")

    {:superhero, id} = superhero_details

    PubSub.broadcast(
      Dispatch.PubSub,
      topic(),
      {:delete_superhero, %Superhero{id: id}}
    )

    {:noreply, state}
  end
end
