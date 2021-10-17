defmodule Muster.Registry do
  use DynamicSupervisor

  def start_link(opts) do
    DynamicSupervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def start_repo(name) do
    repo_id = name |> repo_via()
    spec = %{
      id: Muster.Repository,
      start: {Muster.Repository, :create, [[name, repo_id]]}
    }
    DynamicSupervisor.start_child(__MODULE__, spec)
  end

  @impl true
  def init(_opts) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def repo_via(name), do: {:via, Registry, {RepoPidRegistry, name}}

  def start_upload_monolithic(repo_name) do
    repo_name |> repo_via |>
    GenServer.call(:start_upload)
  end

  def start_upload_chunked(repo_name) do
    repo_name |> repo_via |>
    GenServer.call(:start_upload_chunked)
  end

  def monolithic_upload(repo_name, location, digest, blob) do
    repo_name |> repo_via |>
    GenServer.call({:upload_monolithic, location, digest, blob})
  end

  def chunk_upload(repo_name, location, range, blob) do
    repo_name |> repo_via |>
    GenServer.call({:upload_chunk, location, range, blob})
  end

  # Final PUT to close upload session
  def complete_upload(repo_name, location, digest) do
    repo_name |> repo_via |>
    GenServer.call({:complete_upload, location, digest})
  end

  # Final PUT to close upload session with final chunk
  def complete_upload(repo_name, location, digest, range, blob) do
    repo_name |> repo_via |>
    GenServer.call({:complete_upload, location, digest, range, blob})
  end

  def upload_manifest(repo_name, reference, %{} = manifest) do
    repo_name |> repo_via |>
    GenServer.call({:upload_manifest, reference, manifest})
  end

  def list_tags(repo_name, n \\ nil, last \\ nil) do
    repo_name |> repo_via() |>
    GenServer.call({:list_tags, {n, last}})
  end

  def manifest_exists?(repo_name, reference) do
    repo_name |> repo_via() |>
    GenServer.call({:check_manifest, reference})
  end

  def get_manifest(repo_name, reference) do
    repo_name |> repo_via() |>
    GenServer.call({:get_manifest, reference})
  end

  def layer_exists?(repo_name, digest) do
    repo_name |> repo_via() |>
    GenServer.call({:check_layer, digest})
  end

  def get_layer(repo_name, digest) do
    repo_name |> repo_via() |>
    GenServer.call({:get_layer, digest})
  end

  def delete_tag(repo_name, _reference) do
    {:error, :unsupported}
  end

  def delete_manifest(repo_name, _reference) do
    {:error, :unsupported}
  end

  @spec delete_layer(any, any) :: {:error, :unsupported}
  def delete_layer(repo_name, _reference) do
    {:error, :unsupported}
  end
end
