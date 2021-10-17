defmodule PullTest do
  use ExUnit.Case

  test "manifest exists? not found" do
    repo = UUID.uuid4
    {:ok, _} = Muster.Registry.start_repo(repo)
    false = Muster.Registry.manifest_exists?(repo, UUID.uuid4)
  end

  test "manifest exists?" do
    repo = UUID.uuid4
    {:ok, _} = Muster.Registry.start_repo(repo)
    manifest_ref = MusterTest.upload_layer(repo)
    true = Muster.Registry.manifest_exists?(repo, manifest_ref)
  end

  test "get manfiest not found" do
    repo = UUID.uuid4
    {:ok, _} = Muster.Registry.start_repo(repo)
    {:error, :not_found} = Muster.Registry.get_manifest(repo, UUID.uuid4)
  end

  test "get manfiest" do
    repo = UUID.uuid4
    {:ok, _} = Muster.Registry.start_repo(repo)
    reference = MusterTest.upload_layer(repo)
    {:ok, %{} = manifest} = Muster.Registry.get_manifest(repo, reference)
  end

  test "layer_exists? not found" do
    repo = UUID.uuid4
    {:ok, _} = Muster.Registry.start_repo(repo)
    false = Muster.Registry.layer_exists?(repo, UUID.uuid4)
  end

  test "layer_exists?" do
    repo = UUID.uuid4
    {:ok, _} = Muster.Registry.start_repo(repo)
    reference = MusterTest.upload_layer(repo)
    {:ok, %{layers: [%{digest: layer_digest}]} = manifest} = Muster.Registry.get_manifest(repo, reference)
    true = Muster.Registry.layer_exists?(repo, layer_digest)
  end

  test "get layer" do
    repo = UUID.uuid4
    {:ok, _} = Muster.Registry.start_repo(repo)
    reference = MusterTest.upload_layer(repo)
    {:ok, %{layers: [%{digest: layer_digest}]} = manifest} = Muster.Registry.get_manifest(repo, reference)
    {:ok, blob} = Muster.Registry.get_layer(repo, layer_digest)
    assert is_binary(blob) && byte_size(blob) > 0, "Did not get blob"
  end
end
