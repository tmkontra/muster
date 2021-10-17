defmodule ContentManagementTest do
  use ExUnit.Case

  test "delete manifest unsupported" do
    repo = UUID.uuid4
    {:ok, _} = Muster.Registry.start_repo(repo)
    {:error, :unsupported} = Muster.Registry.delete_manifest(repo, UUID.uuid4)
  end

  test "delete tag unsupported" do
    repo = UUID.uuid4
    {:ok, _} = Muster.Registry.start_repo(repo)
    {:error, :unsupported} = Muster.Registry.delete_tag(repo, UUID.uuid4)
  end

  test "delete layer unsupported" do
    repo = UUID.uuid4
    {:ok, _} = Muster.Registry.start_repo(repo)
    {:error, :unsupported} = Muster.Registry.delete_layer(repo, UUID.uuid4)
  end
end
