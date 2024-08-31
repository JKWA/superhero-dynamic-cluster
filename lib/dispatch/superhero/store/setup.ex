defmodule Dispatch.Store.Setup do
  use GenServer
  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    Keyword.get(opts, :nodes, [])
    |> setup_mnesia()
    |> create_superhero_table()

    :mnesia.wait_for_tables([:superhero], 5000)
    {:ok, %{}}
  end

  defp setup_mnesia(nodes) do
    :mnesia.create_schema([Node.self()])
    :mnesia.start()
    :mnesia.change_config(:extra_db_nodes, nodes)
    Logger.info("Mnesia configured with nodes: #{inspect(nodes)}")
    nodes
  end

  defp create_superhero_table(nodes) do
    Logger.info("Creating superhero table on #{Node.self()}.")

    case :mnesia.create_table(:superhero, superhero_table_opts(nodes)) do
      {:atomic, :ok} ->
        Logger.info("Superhero table created successfully.")

      {:aborted, {:already_exists, table}} ->
        Logger.info("#{table} table already exists.")
    end

    nodes
  end

  defp superhero_table_opts(nodes) do
    [
      {:attributes,
       [:id, :name, :node, :is_patrolling, :last_updated, :fights_won, :fights_lost, :health]},
      {:ram_copies, nodes},
      {:type, :set}
    ]
  end
end
