defmodule Dispatch.Store.SuperheroStore do
  alias Dispatch.Superhero
  require Logger

  def upsert_superhero(%{id: id} = superhero) do
    superhero_tuple =
      %Superhero{id: id}
      |> Map.merge(superhero)
      |> Map.put(:last_updated, System.system_time(:second))
      |> convert_to_tuple()
      |> Tuple.insert_at(0, :superhero)

    transaction_result =
      :mnesia.transaction(fn ->
        :mnesia.write(superhero_tuple)
        :ok
      end)

    case transaction_result do
      {:atomic, :ok} ->
        {:ok, superhero}

      {:aborted, reason} ->
        Logger.error("Failed to upsert superhero #{id} from Mnesia: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def get_superhero(id) do
    transaction_result =
      :mnesia.transaction(fn ->
        :mnesia.read({:superhero, id})
      end)

    case transaction_result do
      {:atomic, [head]} ->
        superhero =
          head
          |> Tuple.delete_at(0)
          |> convert_to_struct()

        {:ok, superhero}

      {:atomic, []} ->
        {:error, :not_found}

      {:aborted, reason} ->
        Logger.error("Failed to get superhero #{id} from Mnesia: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def get_all_superheroes do
    result =
      :mnesia.transaction(fn ->
        :mnesia.match_object({:superhero, :_, :_, :_, :_, :_, :_, :_, :_})
      end)

    case result do
      {:atomic, data} when data != [] ->
        superheroes =
          Enum.map(data, fn tuple ->
            tuple
            |> Tuple.delete_at(0)
            |> convert_to_struct()
          end)

        {:ok, superheroes}

      {:atomic, []} ->
        {:ok, []}

      {:aborted, reason} ->
        Logger.error("Failed to get superheroes from Mnesia: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def delete_superhero(id) do
    result =
      :mnesia.transaction(fn ->
        :mnesia.delete({:superhero, id})
      end)

    case result do
      {:atomic, :ok} ->
        {:ok, :deleted}

      {:aborted, reason} ->
        Logger.error("Failed to delete superhero #{id} from Mnesia: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp convert_to_tuple(%Superhero{
         id: id,
         name: name,
         node: node,
         is_patrolling: is_patrolling,
         last_updated: last_updated,
         fights_won: fights_won,
         fights_lost: fights_lost,
         health: health
       }) do
    {id, name, node, is_patrolling, last_updated, fights_won, fights_lost, health}
  end

  defp convert_to_struct(
         {id, name, node, is_patrolling, last_updated, fights_won, fights_lost, health}
       ) do
    %Superhero{
      id: id,
      name: name,
      node: node,
      is_patrolling: is_patrolling,
      last_updated: last_updated,
      fights_won: fights_won,
      fights_lost: fights_lost,
      health: health
    }
  end
end
