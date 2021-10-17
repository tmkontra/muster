defmodule MusterApi.RegistryConnTest do
  use MusterApi.ConnCase

  test "get repo", %{conn: conn} do
    {:ok, _pid} = Muster.Registry.start_repo("my-image")
  end
end
