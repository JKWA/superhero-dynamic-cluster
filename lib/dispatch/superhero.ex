defmodule Dispatch.Superhero do
  @enforce_keys [:name]
  defstruct name: nil,
            is_patrolling: false,
            last_updated: 0,
            fights_won: 0,
            fights_lost: 0,
            health: 100

  def get_state(name) do
    %{
      name: name,
      is_patrolling: false,
      last_updated: System.system_time(:second),
      fights_won: 0,
      fights_lost: 0,
      health: 100
    }
  end
end
