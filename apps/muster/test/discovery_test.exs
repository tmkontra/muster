defmodule DiscoveryTest do
  use ExUnit.Case
  use Muster.RegistryCase

  test "list tags empty" do
    repo = UUID.uuid4
    {:ok, _} = Muster.Registry.start_repo(repo)
    [] = Muster.Registry.list_tags(repo)
  end

  test "list tags" do
    repo = UUID.uuid4
    {:ok, _} = Muster.Registry.start_repo(repo)
    upload_layer(repo)
    [] = Muster.Registry.list_tags(repo)
  end
end
