defmodule PullTest do
  use ExUnit.Case
  use Muster.RepositoryCase

  test "manifest exists? not found" do
    repo = UUID.uuid4
    {:ok, repo} = Muster.Repository.create(repo)
    false = Muster.Repository.manifest_exists?(repo, UUID.uuid4)
  end

  test "manifest exists?" do
    repo = UUID.uuid4
    {:ok, repo} = Muster.Repository.create(repo)
    manifest_ref = upload_manifest(repo)
    true = Muster.Repository.manifest_exists?(repo, manifest_ref)
  end

  test "get manfiest not found" do
    repo = UUID.uuid4
    {:ok, repo} = Muster.Repository.create(repo)
    {:error, :not_found} = Muster.Repository.get_manifest(repo, UUID.uuid4)
  end

  test "get manfiest" do
    repo = UUID.uuid4
    {:ok, repo} = Muster.Repository.create(repo)
    reference = upload_manifest(repo)
    {:ok, %{} = manifest} = Muster.Repository.get_manifest(repo, reference)
  end

  test "layer_exists? not found" do
    repo = UUID.uuid4
    {:ok, repo} = Muster.Repository.create(repo)
    false = Muster.Repository.layer_exists?(repo, UUID.uuid4)
  end

  test "layer_exists?" do
    repo = UUID.uuid4
    {:ok, repo} = Muster.Repository.create(repo)
    layer_digest = upload_layer(repo)
    true = Muster.Repository.layer_exists?(repo, layer_digest)
  end

  test "get layer" do
    repo = UUID.uuid4
    {:ok, repo} = Muster.Repository.create(repo)
    layer_digest = upload_layer(repo)
    {:ok, blob} = Muster.Repository.get_layer(repo, layer_digest)
    assert is_binary(blob) && byte_size(blob) > 0, "Did not get blob"
  end
end
