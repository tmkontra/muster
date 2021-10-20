defmodule Muster.Repository do
  alias Muster.Model.{MonolithicUploadRequest, ChunkedUploadRequest, CompleteUploadRequest, ManifestUploadRequest, ListTagsRequest}

  @spec create(any, atom | {:global, any} | {:via, atom, any}) ::
          :ignore | {:error, any} | {:ok, pid}
  def create(name, id) do
    GenServer.start_link(Muster.Repository.Server, name, name: id)
  end

  @spec create(any) :: :ignore | {:error, any} | {:ok, pid}
  def create(name) do
    GenServer.start_link(Muster.Repository.Server, name)
  end

  def start_upload_monolithic(repo) do
    GenServer.call(repo, :start_upload)
  end

  @spec start_upload_chunked(atom | pid | {atom, any} | {:via, atom, any}) :: any
  def start_upload_chunked(repo) do
    GenServer.call(repo, :start_upload_chunked)
  end

  def monolithic_upload(repo, location, digest, blob) do
    GenServer.call(repo, {:upload_monolithic, %MonolithicUploadRequest{upload_id: location, digest: digest, blob: blob}})
  end

  def chunk_upload(repo, location, range, blob) do
    GenServer.call(repo, {:upload_chunk, %ChunkedUploadRequest{upload_id: location, range: range, blob: blob}})
  end

  # Final PUT to close upload session
  def complete_upload(repo, location, digest) do
    GenServer.call(repo, {:complete_upload, %CompleteUploadRequest{upload_id: location, digest: digest}})
  end

  # Final PUT to close upload session with final chunk
  def complete_upload(repo, location, digest, range, blob) do
    GenServer.call(repo, {:complete_upload, %CompleteUploadRequest{upload_id: location, digest: digest, range: range, blob: blob}})
  end

  def upload_manifest(repo, reference, %{} = manifest, manifest_digest) do
    GenServer.call(repo, {:upload_manifest, %ManifestUploadRequest{reference: reference, manifest: manifest, manifest_digest: manifest_digest}})
  end

  def list_tags(repo, n \\ nil, last \\ nil) do
    GenServer.call(repo, {:list_tags, %ListTagsRequest{n: n, last: last}})
  end

  def manifest_exists?(repo, reference) do
    GenServer.call(repo, {:check_manifest, reference})
  end

  def get_manifest(repo, reference) do
    GenServer.call(repo, {:get_manifest, reference})
  end

  def layer_exists?(repo, digest) do
    GenServer.call(repo, {:check_layer, digest})
  end

  def get_layer(repo, digest) do
    GenServer.call(repo, {:get_layer, digest})
  end

  def delete_tag(_repo, _reference) do
    unsupported()
  end

  def delete_manifest(_repo, _reference) do
    unsupported()
  end

  def delete_layer(_repo, _reference) do
    unsupported()
  end

  def unsupported(), do: {:error, :unsupported}
end
