defmodule Muster.Repository.Server do
  use GenServer, restart: :temporary
  require Logger
  alias Muster.Repository

  alias Muster.Model.{
    MonolithicUploadRequest,
    ChunkedUploadRequest,
    CompleteUploadRequest,
    ManifestUploadRequest,
    ListTagsRequest
  }

  @impl GenServer
  @spec init(any) ::
          {:ok,
           %Muster.Repository.Impl{
             layers: %{},
             manifests: %{},
             name: any,
             tags: %{},
             uploads: %{}
           }}
  def init(name) do
    {
      :ok,
      Repository.Impl.new(name)
    }
  end

  # Start monolithic upload
  @impl GenServer
  def handle_call(:start_upload, _from, state) do
    {location, state} = Repository.Impl.new_upload(state, :monolithic)
    {:reply, %{location: location}, state}
  end

  # Signature for "single request monolithic upload", returns location
  # to indicate a subsequent PUT is required
  @impl GenServer
  def handle_call({:start_upload, _digest}, _from, state) do
    {location, state} = Repository.Impl.new_upload(state, :monolithic)
    {:reply, %{location: location}, state}
  end

  # Signature for chunked layer upload
  @impl GenServer
  def handle_call(:start_upload_chunked, _from, state) do
    {location, state} = Repository.Impl.new_upload(state, :chunked)
    {:reply, %{location: location}, state}
  end

  @impl GenServer
  def handle_call(
        {:upload_monolithic,
         %MonolithicUploadRequest{upload_id: upload_id, digest: digest, blob: blob}},
        _from,
        state
      ) do
    case Repository.Impl.upload_layer_monolithic(upload_id, digest, blob, state) do
      {:ok, blob_location, state} -> {:reply, %{location: blob_location}, state}
      {:error, _} = err -> {:reply, err, state}
    end
  end

  @impl GenServer
  def handle_call(
        {:upload_chunk,
         %ChunkedUploadRequest{upload_id: upload_id, range: {range_start, range_end}, blob: blob}},
        _from,
        state
      ) do
    case Repository.Impl.upload_layer_chunk(upload_id, range_start, range_end, blob, state) do
      {:ok, state} -> {:reply, %{location: upload_id}, state}
      {:error, cause} -> {:reply, {:error, cause}, state}
    end
  end

  # complete upload with final layer
  @impl GenServer
  def handle_call(
        {:complete_upload,
         %CompleteUploadRequest{
           upload_id: location,
           digest: digest,
           range: range = {_range_start, _range_end},
           blob: blob
         }},
        _from,
        state
      ) do
    case Repository.Impl.finish_upload_session(location, digest, {range, blob}, state) do
      {:ok, location, state} -> {:reply, %{location: location}, state}
      {:error, cause} -> {:reply, {:error, cause}, state}
    end
  end

  @impl GenServer
  def handle_call(
        {:complete_upload,
         %CompleteUploadRequest{upload_id: location, digest: digest, range: nil, blob: nil}},
        _from,
        state
      ) do
    case Repository.Impl.finish_upload_session(location, digest, nil, state) do
      {:ok, location, state} -> {:reply, %{location: location}, state}
      {:error, cause} -> {:reply, {:error, cause}, state}
    end
  end

  @impl GenServer
  def handle_call(
        {:upload_manifest,
         %ManifestUploadRequest{
           reference: reference,
           manifest: manifest,
           manifest_digest: manifest_digest
         }},
        _from,
        state
      ) do
    case Repository.Impl.upload_manifest(reference, manifest, manifest_digest, state) do
      {:ok, {reference, state}} -> {:reply, {:ok, %{location: reference}}, state}
      {:error, :blob_unknown} = error -> {:reply, error, state}
    end
  end

  @impl GenServer
  def handle_call({:list_tags, %ListTagsRequest{} = query}, _from, state) do
    all_tags = Map.keys(state.tags) |> Enum.sort()

    tags =
      case query |> ListTagsRequest.tuple() do
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

  @impl GenServer
  def handle_call(
        {:check_manifest, reference},
        _from,
        %Repository.Impl{manifests: by_reference} = state
      ) do
    exists? = Map.has_key?(by_reference, reference)
    {:reply, exists?, state}
  end

  @impl GenServer
  def handle_call(
        {:get_manifest, reference},
        _from,
        %Repository.Impl{tags: tags, manifests: by_reference = %{}} = state
      ) do
    reply =
      with {:ok, tag} <- Map.fetch(by_reference, reference),
           {:ok, manifest} <- Map.fetch(tags, tag) do
        {:ok, manifest}
      else
        _err -> {:error, :not_found}
      end

    {:reply, reply, state}
  end

  @impl GenServer
  def handle_call({:check_layer, digest}, _from, %{layers: layers} = state) do
    exists? = Map.has_key?(layers, digest)
    {:reply, exists?, state}
  end

  @impl GenServer
  def handle_call({:get_layer, digest}, _from, %{layers: layers} = state) do
    resp =
      case Map.get(layers, digest) do
        nil -> {:error, :not_found}
        blob -> {:ok, blob}
      end

    {:reply, resp, state}
  end
end
