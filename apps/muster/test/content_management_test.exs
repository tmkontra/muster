defmodule ContentManagementTest do
  use ExUnit.Case

  test "delete manifest unsupported" do
    repo = UUID.uuid4()
    {:ok, repo} = Muster.Repository.create(repo)
    {:error, :unsupported} = Muster.Repository.delete_manifest(repo, UUID.uuid4())
  end

  test "delete tag unsupported" do
    repo = UUID.uuid4()
    {:ok, repo} = Muster.Repository.create(repo)
    {:error, :unsupported} = Muster.Repository.delete_tag(repo, UUID.uuid4())
  end

  test "delete layer unsupported" do
    repo = UUID.uuid4()
    {:ok, repo} = Muster.Repository.create(repo)
    {:error, :unsupported} = Muster.Repository.delete_layer(repo, UUID.uuid4())
  end
end
