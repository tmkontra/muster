defmodule Muster.Registry do
  use DynamicSupervisor

  @spec start_link(any) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(opts) do
    DynamicSupervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec start_repo(any) :: :ignore | {:error, any} | {:ok, pid} | {:ok, pid, any}
  def start_repo(name) do
    repo_id = name |> repo_via()

    spec = %{
      id: Muster.Repository,
      start: {Muster.Repository, :create, [name, repo_id]}
    }

    DynamicSupervisor.start_child(__MODULE__, spec)
  end

  @impl true
  def init(_opts) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def repo_via(name), do: {:via, Registry, {RepoPidRegistry, name}}

  def running?(name), do: name |> repo_via() |> Process.alive?()
end
