defmodule Muster.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {DynamicSupervisor, name: Muster.Registry, strategy: :one_for_one},
      {Registry, keys: :unique, name: RepoPidRegistry}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Muster.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
