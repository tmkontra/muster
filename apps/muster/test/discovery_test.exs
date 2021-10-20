defmodule DiscoveryTest do
  use ExUnit.Case
  use Muster.RepositoryCase

  test "list tags empty" do
    repo = UUID.uuid4
    {:ok, repo} = Muster.Repository.create(repo)
    [] = Muster.Repository.list_tags(repo)
  end

  test "list tags" do
    repo = UUID.uuid4
    {:ok, repo} = Muster.Repository.create(repo)
    upload_layer(repo)
    [] = Muster.Repository.list_tags(repo)
  end
end
