defmodule PullTest do
  use ExUnit.Case

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
end
