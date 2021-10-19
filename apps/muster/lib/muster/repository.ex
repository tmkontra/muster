defmodule Muster.Repository do
  use GenServer, restart: :temporary
  require Logger
  alias Muster.Model.{MonolithicUploadRequest, ChunkedUploadRequest, CompleteUploadRequest, ManifestUploadRequest, ListTagsRequest}

  defmodule RepositoryState do
    @enforce_keys [:name, :uploads, :layers, :tags, :manifests]
    defstruct ~w[name uploads layers tags manifests]a
  end

  @spec create([...]) :: :ignore | {:error, any} | {:ok, pid}
  def create([name, id]) do
    GenServer.start_link(__MODULE__, name, name: id)
  end

  def init(name) do
    {
      :ok,
      %RepositoryState{
        name: name,
        uploads: %{}, # upload sessions
        layers: %{}, # digest to layer blob
        tags: %{}, # tag to manifest
        manifests: %{}, # digest to tag, tag to tag -- single source of truth for manifest reference -> tag
      }
    }
  end

  # Start monolithic upload
  def handle_call(:start_upload, _from, state) do
    {location, state} = new_upload(state, :monolithic)
    {:reply, %{location: location}, state}
  end

  # Signature for "single request monolithic upload", returns location
  # to indicate a subsequent PUT is required
  def handle_call({:start_upload, _digest}, _from, state) do
    {location, state} = new_upload(state, :monolithic)
    {:reply, %{location: location}, state}
  end

  # Signature for chunked layer upload
  def handle_call(:start_upload_chunked, _from, state) do
    {location, state} = new_upload(state, :chunked)
    {:reply, %{location: location}, state}
  end

  def handle_call({:upload_monolithic, %MonolithicUploadRequest{upload_id: upload_id, digest: digest, blob: blob}}, _from, state) do
    {:ok, blob_location, state} = upload_layer_monolithic(upload_id, digest, blob, state)
    {:reply, %{location: blob_location}, state}
  end

  def handle_call({:upload_chunk, %ChunkedUploadRequest{upload_id: upload_id, range: {range_start, range_end}, blob: blob}}, _from, state) do
    case upload_layer_chunk(upload_id, range_start, range_end, blob, state) do
      {:ok, state} -> {:reply, %{location: upload_id}, state}
      {:error, cause, state} -> {:reply, {:error, cause}, state}
    end
  end

  # complete upload with final layer
  def handle_call({:complete_upload, %CompleteUploadRequest{upload_id: location, digest: digest, range: range = {_range_start, _range_end}, blob: blob}}, _from, state) do
    {:ok, location, state} = finish_upload_session(location, digest, {range, blob}, state)
    {:reply, %{location: location}, state}
  end

  def handle_call({:complete_upload, %CompleteUploadRequest{upload_id: location, digest: digest, range: nil, blob: nil}}, _from, state) do
    {:ok, location, state} = finish_upload_session(location, digest, nil, state)
    {:reply, %{location: location}, state}
  end

  def handle_call({:upload_manifest, %ManifestUploadRequest{reference: reference, manifest: %{"layers" => manifest_layers} = manifest, manifest_digest: manifest_digest}}, _from, %RepositoryState{} = state) do
    valid = manifest_layers
    |> Enum.map(fn %{"digest" => digest} -> digest end)
    |> Enum.all?(fn digest -> Map.has_key?(state.layers, digest) end)
    case valid do
      true ->
        tags = Map.put(state.tags, reference, manifest)
        manifests = Map.put(state.manifests, manifest_digest, reference) |> Map.put(reference, reference)
        state = %{state | tags: tags, manifests: manifests}
        {:reply, {:ok, %{location: reference}}, state}
      false -> {:reply, {:error, :blob_unknown}, state}
    end
  end

  def handle_call({:list_tags, %ListTagsRequest{} = query}, _from, %RepositoryState{} = state) do
    all_tags = Map.keys(state.tags) |> Enum.sort()
    tags = case query |> ListTagsRequest.tuple do
      {nil, nil} ->
        all_tags
      {0, nil} ->
        []
      {n, nil} ->
        all_tags |> Enum.take(n)
      {nil, last} ->
        all_tags |> Enum.drop_while(fn t -> t != last end) |> Enum.drop(1)
      {n, last} ->
        all_tags |> Enum.drop_while(fn t -> t != last end) |> Enum.drop(1) |> Enum.take(n)
    end
    {:reply, tags, state}
  end

  def handle_call({:check_manifest, reference}, _from, %RepositoryState{manifests: by_reference} = state) do
    exists? = Map.has_key?(by_reference, reference)
    {:reply, exists?, state}
  end

  def handle_call({:get_manifest, reference}, _from, %{tags: tags, manifests: by_reference = %{}} = state) do
    reply = with {:ok, tag} <- Map.fetch(by_reference, reference),
         {:ok, manifest} <- Map.fetch(tags, tag)
         do
          {:ok, manifest}
         else
          _err -> {:error, :not_found}
         end
    {:reply, reply, state}
  end

  def handle_call({:check_layer, digest}, _from, %{layers: layers} = state) do
    exists? = Map.has_key?(layers, digest)
    {:reply, exists?, state}
  end

  def handle_call({:get_layer, digest}, _from, %{layers: layers} = state) do
    resp = case Map.get(layers, digest) do
      nil -> {:error, :not_found}
      blob -> {:ok, blob}
    end
    {:reply, resp, state}
  end

  defp new_upload(%{uploads: %{} = uploads} = state, type) do
    upload_value = case type do
      :monolithic -> nil
      :chunked -> []
    end
    location = UUID.uuid4()
    uploads = Map.put(uploads, location, {:started, upload_value})
    state = %{state | uploads: uploads}
    {location, state}
  end

  defp upload_layer_monolithic(upload_id, digest, blob, %{uploads: uploads, layers: layers} = state) do
    with {:ok, {:started, _any}} <- Map.fetch(uploads, upload_id)
      do
        layers = Map.put(layers, digest, blob)
        uploads = Map.put(uploads, upload_id, {:completed, []})
        state = %{state | layers: layers, uploads: uploads}
        {:ok, digest, state}
      else _err ->
        {:error, "Unable to accept monolithic layer upload"}
      end
  end

  defp upload_layer_chunk(upload_id, range_start, range_end, blob, %{uploads: uploads} = state) do
    with {:ok, {:started, chunks}} when is_list(chunks) <- Map.fetch(uploads, upload_id),
         {:ok, chunks} <- verify_chunk_order(chunks, range_start, range_end, blob)
    do
      uploads = Map.put(uploads, upload_id, {:started, chunks})
      state = %{state | uploads: uploads}
      {:ok, state}
    else
      {:ok, {:started, nil}} -> {:error, :monolithic_only, state}
      {:error, cause} -> {:error, cause, state}
      error -> {:error, error, state}
    end
  end

  defp verify_chunk_order(chunks, range_start, range_end, blob) do
    chunks = case chunks do
      [] when range_start == 0 -> [{range_end, blob}]
      chunks = [{prev_end, _blob} | _tail = []] when prev_end + 1 == range_start -> [{range_end, blob} | chunks]
      chunks = [{prev_end, blob} | _tail] when prev_end + 1 == range_start -> [{range_end, blob} | chunks]
      _ ->
        Logger.warn("Got invalid chunk sequence for range '#{range_start}-#{range_end}'")
        :error
    end
    case chunks do
      :error -> {:error, :illegal_chunk_sequence}
      chunk_list -> {:ok, chunk_list}
    end
  end

  defp finish_upload_session(upload_id, digest, maybe_content, %RepositoryState{} = state) do
    case Map.fetch(state.uploads, upload_id) do
      {:ok, {:started, _chunks}} ->
        {:ok, state} = case maybe_content do
          nil -> {:ok, state}
          {{range_start, range_end}, blob} -> upload_layer_chunk(upload_id, range_start, range_end, blob, state)
        end
        {:started, chunks} = Map.fetch!(state.uploads, upload_id)
        layers = put_layer(digest, chunks, state.layers)
        uploads = Map.put(state.uploads, upload_id, {:completed, []})
        {:ok, digest, %{state | layers: layers, uploads: uploads}}
      error -> {:error, error}
    end
  end

  defp put_layer(digest, chunks, layers_state) do
    layer = chunks
    |> Enum.map(fn {_, blob} -> blob end)
    |> Enum.reduce(<<>>, fn (a, b) -> a <> b end)
    Map.put(layers_state, digest, layer)
  end
end
