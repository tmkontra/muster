defmodule DiscoveryTest do
  use ExUnit.Case

  test "list tags empty" do
    repo = UUID.uuid4
    {:ok, _} = Muster.Registry.start_repo(repo)
    [] = Muster.Registry.list_tags(repo)
  end

  test "list tags" do
    repo = UUID.uuid4
    {:ok, _} = Muster.Registry.start_repo(repo)
    MusterTest.upload_layer(repo)
    [tag] = Muster.Registry.list_tags(repo)
  end
end
