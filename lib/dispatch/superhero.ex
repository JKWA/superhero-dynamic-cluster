defmodule Dispatch.Superhero do
  @enforce_keys [:id]
  defstruct id: nil,
            name: nil,
            node: nil,
            is_patrolling: false,
            last_updated: 0,
            fights_won: 0,
            fights_lost: 0,
            health: 100
end
