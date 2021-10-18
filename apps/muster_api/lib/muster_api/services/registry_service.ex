defmodule MusterApi.RegistryService do
  use MusterApi, :service

  def start_upload(namespace, name, type) do
    repo = namespace<>name
    with_repo repo do
      case type do
        :monolithic -> Muster.Registry.start_upload_monolithic(repo)
        :chunked -> Muster.Registry.start_upload_chunked(repo)
      end
    end
  end

  def upload_blob(namespace, name, location, digest, blob) do
    repo = namespace<>name
    with_repo repo, do: Muster.Registry.monolithic_upload(repo, location, digest, blob)
  end

  def upload_blob_chunk(namespace, name, location, range, blob) do
    repo = namespace<>name
    with_repo repo, do: Muster.Registry.chunk_upload(repo, location, range, blob)
  end

  def upload_final_blob_chunk(namespace, name, location, digest, blob, range \\ nil) do
    repo = namespace<>name
    with_repo repo do
      case range do
        nil -> Muster.Registry.complete_upload(repo, location, digest)
        {_, _} -> Muster.Registry.complete_upload(repo, location, digest, range, blob)
      end
    end
  end

  def upload_manifest(namespace, name, reference, manifest, manifest_digest) do
    repo = namespace<>name
    with_repo repo, do: Muster.Registry.upload_manifest(repo, reference, manifest, manifest_digest)
  end

  def get_blob(namespace, name, digest) do
    repo = namespace<>name
    with_repo repo do
      Muster.Registry.get_layer(repo, digest)
    end
  end

  def blob_exists?(namespace, name, digest) do
    repo = namespace<>name
    with_repo repo, do: Muster.Registry.blob_exists?(repo, digest)
  end

  def get_manifest(namespace, name, reference) do
    repo = namespace<>name
    with_repo repo, do: Muster.Registry.get_manifest(repo, reference)
  end

  def manifest_exists?(namespace, name, reference) do
    repo = namespace <> name
    with_repo repo, do: Muster.Registry.manifest_exists?(repo, reference)
  end
end
