defmodule MusterApi.RegistryService do
  import MusterApi.RepoService

  def start_upload(namespace, name, type) do
    repo = namespace <> name

    with_repo(repo, fn repo ->
      case type do
        :monolithic -> Muster.Repository.start_upload_monolithic(repo)
        :chunked -> Muster.Repository.start_upload_chunked(repo)
      end
    end)
  end

  def upload_blob(namespace, name, location, digest, blob) do
    repo = namespace <> name
    with_repo(repo, &Muster.Repository.monolithic_upload(&1, location, digest, blob))
  end

  def upload_blob_chunk(namespace, name, location, range, blob) do
    repo = namespace <> name
    with_repo(repo, &Muster.Repository.chunk_upload(&1, location, range, blob))
  end

  def upload_final_blob_chunk(namespace, name, location, digest, blob, range \\ nil) do
    repo = namespace <> name

    with_repo(repo, fn repo ->
      case range do
        nil -> Muster.Repository.complete_upload(repo, location, digest)
        {_, _} -> Muster.Repository.complete_upload(repo, location, digest, range, blob)
      end
    end)
  end

  def upload_manifest(namespace, name, reference, manifest, manifest_digest) do
    repo = namespace <> name
    with_repo(repo, &Muster.Repository.upload_manifest(&1, reference, manifest, manifest_digest))
  end

  def get_blob(namespace, name, digest) do
    repo = namespace <> name
    with_repo(repo, &Muster.Repository.get_layer(&1, digest))
  end

  def blob_exists?(namespace, name, digest) do
    repo = namespace <> name
    with_repo(repo, &Muster.Repository.blob_exists?(&1, digest))
  end

  def get_manifest(namespace, name, reference) do
    repo = namespace <> name
    with_repo(repo, &Muster.Repository.get_manifest(&1, reference))
  end

  def manifest_exists?(namespace, name, reference) do
    repo = namespace <> name
    with_repo(repo, &Muster.Repository.manifest_exists?(&1, reference))
  end

  def list_tags(namespace, name, n \\ nil, last \\ nil) do
    repo = namespace <> name
    with_repo(repo, &Muster.Repository.list_tags(&1, n, last))
  end
end
