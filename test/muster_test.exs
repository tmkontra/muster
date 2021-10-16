defmodule MusterTest do
  use ExUnit.Case
  doctest Muster

  def upload_layer(repo) do
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
