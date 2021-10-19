defmodule Muster.Registry do
  use DynamicSupervisor
  alias Muster.Model.{MonolithicUploadRequest, ChunkedUploadRequest, CompleteUploadRequest, ManifestUploadRequest, ListTagsRequest}

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

  def running?(name), do: name |> repo_via() |> Process.alive?()

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
    GenServer.call({:upload_monolithic, %MonolithicUploadRequest{upload_id: location, digest: digest, blob: blob}})
  end

  def chunk_upload(repo_name, location, range, blob) do
    repo_name |> repo_via |>
    GenServer.call({:upload_chunk, %ChunkedUploadRequest{upload_id: location, range: range, blob: blob}})
  end

  # Final PUT to close upload session
  def complete_upload(repo_name, location, digest) do
    repo_name |> repo_via |>
    GenServer.call({:complete_upload, %CompleteUploadRequest{upload_id: location, digest: digest}})
  end

  # Final PUT to close upload session with final chunk
  def complete_upload(repo_name, location, digest, range, blob) do
    repo_name |> repo_via |>
    GenServer.call({:complete_upload, %CompleteUploadRequest{upload_id: location, digest: digest, range: range, blob: blob}})
  end

  def upload_manifest(repo_name, reference, %{} = manifest, manifest_digest) do
    repo_name |> repo_via |>
    GenServer.call({:upload_manifest, %ManifestUploadRequest{reference: reference, manifest: manifest, manifest_digest: manifest_digest}})
  end

  def list_tags(repo_name, n \\ nil, last \\ nil) do
    repo_name |> repo_via() |>
    GenServer.call({:list_tags, %ListTagsRequest{n: n, last: last}})
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

  def delete_tag(_repo_name, _reference) do
    unsupported
  end

  def delete_manifest(_repo_name, _reference) do
    unsupported
  end

  def delete_layer(_repo_name, _reference) do
    unsupported
  end

  def unsupported(), do: {:error, :unsupported}
end
