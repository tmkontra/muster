defmodule Muster.Repository do
  use GenServer, restart: :temporary
  require Logger

  def create([name, id]) do
    GenServer.start_link(__MODULE__, name, name: id)
  end

  def init(name) do
    {
      :ok,
      %{
        name: name,
        uploads: %{},
        layers: %{},
        tags: %{}
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

  def handle_call({:upload_monolithic, upload_id, digest, blob}, _from, state) do
    {:ok, blob_location, state} = upload_layer_monolithic(upload_id, digest, blob, state)
    {:reply, %{location: blob_location}, state}
  end

  def handle_call({:upload_chunk, upload_id, {range_start, range_end}, blob}, _from, state) do
    case upload_layer_chunk(upload_id, range_start, range_end, blob, state) do
      {:ok, state} -> {:reply, %{location: upload_id}, state}
      {:error, cause, state} -> {:reply, {:error, cause}, state}
    end
  end

  def handle_call({:complete_upload, location, digest}, _from, state) do
    {:ok, location, state} = finish_upload_session(location, digest, nil, state)
    {:reply, %{location: location}, state}
  end

  def handle_call({:complete_upload, location, digest, {_range_start, _range_end} = range, blob}, _from, state) do
    {:ok, location, state} = finish_upload_session(location, digest, {range, blob}, state)
    {:reply, %{location: location}, state}
  end

  def handle_call({:upload_manifest, reference, %{layers: manifest_layers} = manifest}, _from, %{layers: layers = %{}, tags: tags = %{}} = state) do
    valid = manifest_layers
    |> Enum.map(fn %{digest: digest} -> digest end)
    |> Enum.all?(fn digest -> Map.has_key?(layers, digest) end)
    case valid do
      true ->
        tags = Map.put(tags, reference, manifest)
        state = %{state | tags: tags}
        {:reply, {:ok, %{location: reference}}, state}
      false -> {:reply, {:error, :blob_unknown}, state}
    end
  end

  def handle_call({:list_tags, query}, _from, %{tags: tags} = state) do
    all_tags = Map.keys(tags) |> Enum.sort()
    tags = case query do
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

  def handle_call({:check_manifest, reference}, _from, %{tags: tags} = state) do
    exists? = Map.has_key?(tags, reference)
    {:reply, exists?, state}
  end

  def handle_call({:get_manifest, reference}, _from, %{tags: tags} = state) do
    manifest = case Map.get(tags, reference) do
      nil -> {:error, :not_found}
      manifest -> {:ok, manifest}
    end
    {:reply, manifest, state}
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
      invalid ->
        Logger.warn("Got invalid chunk sequence for range '#{range_start}-#{range_end}': #{invalid}")
        :error
    end
    case chunks do
      :error -> {:error, :illegal_chunk_sequence}
      chunk_list -> {:ok, chunk_list}
    end
  end

  defp finish_upload_session(upload_id, digest, maybe_content, %{uploads: uploads} = state) do
    with {:ok, {:started, _chunks}} <- Map.fetch(uploads, upload_id)
    do
      {:ok, state} = case maybe_content do
        nil -> {:ok, state}
        {{range_start, range_end}, blob} -> upload_layer_chunk(upload_id, range_start, range_end, blob, state)
      end
      %{uploads: uploads, layers: layers} = state
      {:started, chunks} = Map.fetch!(uploads, upload_id)
      layers = put_layer(digest, chunks, layers)
      uploads = Map.put(uploads, upload_id, {:completed, []})
      {:ok, digest, %{state | layers: layers, uploads: uploads}}
    else error ->
      {:error, error}
    end
  end

  defp put_layer(digest, chunks, layers_state) do
    layer = chunks
    |> Enum.map(fn {_, blob} -> blob end)
    |> Enum.reduce(<<>>, fn (a, b) -> a <> b end)
    Map.put(layers_state, digest, layer)
  end
end
