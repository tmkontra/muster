defmodule PushTest do
  use ExUnit.Case
  use Muster.RegistryCase

  test "upload monolithic layer" do
    repo = UUID.uuid4
    {:ok, _} = Muster.Registry.start_repo(repo)
    %{location: location} = Muster.Registry.start_upload_monolithic(repo)
    %{location: location} = Muster.Registry.monolithic_upload(repo, location, "abc123", <<1, 2, 3>>)
  end

  test "upload expecting monolithic layer should reject a chunk" do
    repo = UUID.uuid4
    {:ok, _} = Muster.Registry.start_repo(repo)
    %{location: location} = Muster.Registry.start_upload_monolithic(repo)
    {:error, :monolithic_only} = Muster.Registry.chunk_upload(repo, location, {0, 3}, <<1, 2, 3>>)
  end

  test "upload chunked layer" do
    repo = UUID.uuid4
    {:ok, _} = Muster.Registry.start_repo(repo)
    %{location: location} = Muster.Registry.start_upload_chunked(repo)
    %{location: location} = Muster.Registry.chunk_upload(repo, location, {0, 3}, <<1, 2, 3>>)
    %{location: location} = Muster.Registry.chunk_upload(repo, location, {4, 7}, <<1, 2, 3>>)
    %{location: location} = Muster.Registry.complete_upload(repo, location, "123456")
  end

  test "upload chunked layer, finalize with chunk" do
    digest = "123456"
    repo = UUID.uuid4()
    {:ok, _} = Muster.Registry.start_repo(repo)
  end

  test "upload chunked layer, illegal sequence" do
    digest = "123456"
    repo = UUID.uuid4
    {:ok, _} = Muster.Registry.start_repo(repo)
    %{location: location} = Muster.Registry.start_upload_chunked(repo)
    %{location: location}= Muster.Registry.chunk_upload(repo, location, {0, 2}, <<1, 2, 3>>)
    {:error, :illegal_chunk_sequence} = Muster.Registry.chunk_upload(repo, location, {10, 12}, <<1, 2, 3>>)
  end

  test "upload manifest should error for non-existent layer" do
    digest = "123456"
    repo = UUID.uuid4
    manifest_digest = UUID.uuid4
    {:ok, _} = Muster.Registry.start_repo(repo)
    %{location: location} = Muster.Registry.start_upload_chunked(repo)
    %{location: location} = Muster.Registry.chunk_upload(repo, location, {0, 3}, <<1, 2, 3>>)
    %{location: location} = Muster.Registry.chunk_upload(repo, location, {4, 7}, <<1, 2, 3>>)
    %{location: location} = Muster.Registry.complete_upload(repo, location, digest, {8, 11}, <<1, 2, 3>>)
    {:error, :blob_unknown} = Muster.Registry.upload_manifest(repo, "tag1", %{"layers" => [%{"digest" => digest <> "123124"}]}, manifest_digest)
  end

  test "push tag" do
    repo = UUID.uuid4()
    {:ok, _} = Muster.Registry.start_repo(repo)
    layer_digest = upload_layer(repo)
    manifest = %{
      "layers" => [
        %{"digest" => layer_digest}
      ]
    }
    tag = "abc1234"
    {:ok, %{location: location}} = Muster.Registry.upload_manifest(repo, tag, manifest, UUID.uuid4())
    [^tag] = Muster.Registry.list_tags(repo)
  end
end
