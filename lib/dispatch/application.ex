defmodule Dispatch.Application do
  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    topologies = [
      dispatch_gossip_cluster: [
        strategy: Cluster.Strategy.Gossip,
        config: [
          port: 45892
        ]
      ]
    ]

    children = [
      {Cluster.Supervisor, [topologies, [name: Dispatch.ClusterSupervisor]]},
      {Horde.Registry, name: Dispatch.SuperheroRegistry, keys: :unique, members: :auto},
      {
        Horde.DynamicSupervisor,
        child_spec: {Dispatch.SuperheroServer, restart: :transient},
        name: Dispatch.SuperheroSupervisor,
        strategy: :one_for_one,
        members: :auto,
        distribution_strategy: Horde.UniformDistribution
      },
      DispatchWeb.Telemetry,
      {Phoenix.PubSub, name: Dispatch.PubSub},
      Dispatch.PollServer,
      DispatchWeb.Endpoint
    ]

    opts = [
      strategy: :one_for_one,
      max_restarts: 3,
      max_seconds: 1,
      name: Dispatch.Supervisor
    ]

    Supervisor.start_link(children, opts)
  end

  def shutdown do
    Logger.info("Shutting down application")
    Application.stop(:dispatch)
    :init.stop()
  end

  @impl true
  def config_change(changed, _new, removed) do
    DispatchWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
