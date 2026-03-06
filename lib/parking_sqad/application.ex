defmodule ParkingSqad.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ParkingSqadWeb.Telemetry,
      ParkingSqad.Repo,
      {DNSCluster, query: Application.get_env(:parking_sqad, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: ParkingSqad.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: ParkingSqad.Finch},
      # Start a worker by calling: ParkingSqad.Worker.start_link(arg)
      # {ParkingSqad.Worker, arg},
      # Start to serve requests, typically the last entry
      ParkingSqadWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ParkingSqad.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ParkingSqadWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
