defmodule Muster.Repository.Impl do
  require Logger

  @enforce_keys [:name, :uploads, :layers, :tags, :manifests]
  defstruct ~w[name uploads layers tags manifests]a

  def new(name) do
    %__MODULE__{
      name: name,
      # upload sessions
      uploads: %{},
      # digest to layer blob
      layers: %{},
      # tag to manifest
      tags: %{},
      # digest to tag, tag to tag -- single source of truth for manifest reference -> tag
      manifests: %{}
    }
  end

  def new_upload(%__MODULE__{uploads: %{} = uploads} = state, type) do
    upload_value =
      case type do
        :monolithic -> nil
        :chunked -> []
      end

    location = UUID.uuid4()
    uploads = Map.put(uploads, location, {:started, upload_value})
    state = %{state | uploads: uploads}
    {location, state}
  end

  def upload_layer_monolithic(
        upload_id,
        digest,
        blob,
        %__MODULE__{uploads: uploads, layers: layers} = state
      ) do
    with {:ok, {:started, _any}} <- Map.fetch(uploads, upload_id) do
      layers = Map.put(layers, digest, blob)
      uploads = Map.put(uploads, upload_id, {:completed, []})
      state = %{state | layers: layers, uploads: uploads}
      {:ok, digest, state}
    else
      _err ->
        {:error, "Unable to accept monolithic layer upload"}
    end
  end

  def upload_layer_chunk(
        upload_id,
        range_start,
        range_end,
        blob,
        %__MODULE__{uploads: uploads} = state
      ) do
    with {:ok, {:started, chunks}} when is_list(chunks) <- Map.fetch(uploads, upload_id),
         {:ok, chunks} <- verify_chunk_order(chunks, range_start, range_end, blob) do
      uploads = Map.put(uploads, upload_id, {:started, chunks})
      state = %{state | uploads: uploads}
      {:ok, state}
    else
      {:ok, {:started, nil}} -> {:error, :monolithic_only}
      {:error, cause} -> {:error, cause}
      error -> {:error, error}
    end
  end

  defp verify_chunk_order(chunks, range_start, range_end, blob) do
    chunks =
      case chunks do
        [] when range_start == 0 ->
          [{range_end, blob}]

        chunks = [{prev_end, _blob} | _tail = []] when prev_end + 1 == range_start ->
          [{range_end, blob} | chunks]

        chunks = [{prev_end, blob} | _tail] when prev_end + 1 == range_start ->
          [{range_end, blob} | chunks]

        _ ->
          Logger.warn("Got invalid chunk sequence for range '#{range_start}-#{range_end}'")
          :error
      end

    case chunks do
      :error -> {:error, :illegal_chunk_sequence}
      chunk_list -> {:ok, chunk_list}
    end
  end

  def finish_upload_session(upload_id, digest, maybe_content, %__MODULE__{} = state) do
    case Map.fetch(state.uploads, upload_id) do
      {:ok, {:started, _chunks}} ->
        {:ok, state} =
          case maybe_content do
            nil ->
              {:ok, state}

            {{range_start, range_end}, blob} ->
              upload_layer_chunk(upload_id, range_start, range_end, blob, state)
          end

        {:started, chunks} = Map.fetch!(state.uploads, upload_id)
        layers = put_layer(digest, chunks, state.layers)
        uploads = Map.put(state.uploads, upload_id, {:completed, []})
        {:ok, digest, %{state | layers: layers, uploads: uploads}}

      :error ->
        {:error, :not_found}
    end
  end

  defp put_layer(digest, chunks, layers_state) do
    layer =
      chunks
      |> Enum.map(fn {_, blob} -> blob end)
      |> Enum.reduce(<<>>, fn a, b -> a <> b end)

    Map.put(layers_state, digest, layer)
  end

  def upload_manifest(
        reference,
        %{"layers" => manifest_layers} = manifest,
        manifest_digest,
        %__MODULE__{} = state
      ) do
    case manifest_layers
         |> Enum.map(fn %{"digest" => digest} -> digest end)
         |> Enum.all?(&Map.has_key?(state.layers, &1)) do
      true ->
        state = state |> put_manifest(reference, manifest_digest, manifest)
        {:ok, {reference, state}}

      false ->
        {:error, :blob_unknown}
    end
  end

  defp put_manifest(%__MODULE__{} = state, reference, digest, manifest) do
    tags = Map.put(state.tags, reference, manifest)
    manifests = Map.put(state.manifests, digest, reference) |> Map.put(reference, reference)
    %{state | tags: tags, manifests: manifests}
  end
end
