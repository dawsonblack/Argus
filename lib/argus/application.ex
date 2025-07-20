defmodule Argus.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ArgusWeb.Telemetry,
      Argus.Repo,
      {DNSCluster, query: Application.get_env(:argus, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Argus.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Argus.Finch},
      # Start a worker by calling: Argus.Worker.start_link(arg)
      # {Argus.Worker, arg},
      # Start to serve requests, typically the last entry
      ArgusWeb.Endpoint,

      {Registry, keys: :unique, name: Argus.DeviceRegistry},
      Argus.DeviceSupervisor
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Argus.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ArgusWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
