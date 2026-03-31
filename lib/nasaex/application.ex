defmodule Nasaex.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      NasaexWeb.Telemetry,
      Nasaex.Repo,
      {DNSCluster, query: Application.get_env(:nasaex, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Nasaex.PubSub},
      # Start a worker by calling: Nasaex.Worker.start_link(arg)
      # {Nasaex.Worker, arg},
      # Start to serve requests, typically the last entry
      NasaexWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Nasaex.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    NasaexWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
