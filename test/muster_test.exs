defmodule MusterTest do
  use ExUnit.Case
  doctest Muster

  test "upload monolithic layer" do
    repo = "my-image"
    {:ok, _} = Muster.Registry.start_link([])
    {:ok, _} = Muster.Registry.start_repo(repo)
    %{location: location} = Muster.Registry.start_upload_monolithic(repo)
    %{location: location} = Muster.Registry.monolithic_upload(repo, location, "abc123", <<1, 2, 3>>)
  end

  test "upload expecting monolithic layer should reject a chunk" do
    repo = "my-image"
    {:ok, _} = Muster.Registry.start_link([])
    {:ok, _} = Muster.Registry.start_repo(repo)
    %{location: location} = Muster.Registry.start_upload_monolithic(repo)
    {:error, :monolithic_only} = Muster.Registry.chunk_upload(repo, location, {0, 3}, <<1, 2, 3>>)
  end

  test "upload chunked layer" do
    repo = "my-image"
    {:ok, _} = Muster.Registry.start_link([])
    {:ok, _} = Muster.Registry.start_repo(repo)
    %{location: location} = Muster.Registry.start_upload_chunked(repo)
    %{location: location} = Muster.Registry.chunk_upload(repo, location, {0, 3}, <<1, 2, 3>>)
    %{location: location} = Muster.Registry.chunk_upload(repo, location, {4, 7}, <<1, 2, 3>>)
    %{location: location} = Muster.Registry.complete_upload(repo, location, "123456")
  end

  test "upload chunked layer, finalize with chunk" do
    digest = "123456"
    repo = "my-image"
    {:ok, _} = Muster.Registry.start_link([])
    {:ok, _} = Muster.Registry.start_repo(repo)
  end

  test "upload chunked layer, illegal sequence" do
    digest = "123456"
    repo = "my-image"
    {:ok, _} = Muster.Registry.start_link([])
    {:ok, _} = Muster.Registry.start_repo(repo)
    %{location: location} = Muster.Registry.start_upload_chunked(repo)
    %{location: location}= Muster.Registry.chunk_upload(repo, location, {0, 2}, <<1, 2, 3>>)
    {:error, :illegal_chunk_sequence} = Muster.Registry.chunk_upload(repo, location, {10, 12}, <<1, 2, 3>>)
  end

  test "upload manifest should error for non-existent layer" do
    digest = "123456"
    repo = "my-image"
    {:ok, _} = Muster.Registry.start_link([])
    {:ok, _} = Muster.Registry.start_repo(repo)
    %{location: location} = Muster.Registry.start_upload_chunked(repo)
    %{location: location} = Muster.Registry.chunk_upload(repo, location, {0, 3}, <<1, 2, 3>>)
    %{location: location} = Muster.Registry.chunk_upload(repo, location, {4, 7}, <<1, 2, 3>>)
    %{location: location} = Muster.Registry.complete_upload(repo, location, digest, {8, 11}, <<1, 2, 3>>)
    {:error, :blob_unknown} = Muster.Registry.upload_manifest(repo, "tag1", %{layers: [%{digest: digest <> "123124"}]})
  end

  test "list tags empty" do
    repo = "my-image"
    {:ok, _} = Muster.Registry.start_link([])
    {:ok, _} = Muster.Registry.start_repo(repo)
    [] = Muster.Registry.list_tags(repo)
  end

  test "list tags" do
    repo = "my-image"
    {:ok, _} = Muster.Registry.start_link([])
    {:ok, _} = Muster.Registry.start_repo(repo)
    upload_layer(repo)
    [tag] = Muster.Registry.list_tags(repo)
  end

  test "get manfiest not found" do
    repo = "my-image"
    {:ok, _} = Muster.Registry.start_link([])
    {:ok, _} = Muster.Registry.start_repo(repo)
    {:error, :not_found} = Muster.Registry.get_manifest(repo, UUID.uuid4)
  end

  test "get manfiest" do
    repo = "my-image"
    {:ok, _} = Muster.Registry.start_link([])
    {:ok, _} = Muster.Registry.start_repo(repo)
    reference = upload_layer(repo)
    {:ok, %{} = manifest} = Muster.Registry.get_manifest(repo, reference)
  end

  defp upload_layer(repo) do
    digest = UUID.uuid4()
    tag = UUID.uuid4()
    %{location: location} = Muster.Registry.start_upload_chunked(repo)
    %{location: location} = Muster.Registry.chunk_upload(repo, location, {0, 3}, <<1, 2, 3>>)
    %{location: location} = Muster.Registry.chunk_upload(repo, location, {4, 7}, <<1, 2, 3>>)
    %{location: location} = Muster.Registry.complete_upload(repo, location, digest, {8, 11}, <<1, 2, 3>>)
    {:ok, %{location: reference}} = Muster.Registry.upload_manifest(repo, tag, %{layers: [%{digest: digest}]})
    reference
  end
end
