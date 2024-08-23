defmodule Dispatch.PollServer do
  use GenServer
  alias Dispatch.SuperheroApi
  alias Phoenix.PubSub
  require Logger

  @poll_interval 2_000
  @poll_topic "data_topic"

  def topic do
    @poll_topic
  end

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def start_poll do
    GenServer.cast(__MODULE__, :start_poll)
  end

  @impl true
  def init(state) do
    schedule_poll()
    {:ok, state}
  end

  @impl true
  def handle_cast(:start_poll, state) do
    poll()
    schedule_poll()
    {:noreply, state}
  end

  @impl true
  def handle_info(:poll, state) do
    poll()
    schedule_poll()
    {:noreply, state}
  end

  defp schedule_poll do
    Process.send_after(self(), :poll, @poll_interval)
  end

  defp poll do
    data = SuperheroApi.get_all_superheroes_with_details()

    PubSub.broadcast(
      Dispatch.PubSub,
      @poll_topic,
      {:update_data, data}
    )
  end
end
