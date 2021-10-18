defmodule MusterApi.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use MusterApi.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate
  use MusterApi, :service

  using do
    quote do
      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import MusterApi.ConnCase

      alias MusterApi.Router.Helpers, as: Routes

      # The default endpoint for testing
      @endpoint MusterApi.Endpoint

      def random_string(length), do: s = for _ <- 1..length, into: "", do: <<Enum.random('0123456789abcdef')>>

      def upload_manifest(namespace, name) do
        repo = namespace<>name
        with_repo repo do
          layer_digest = upload_layer(repo)
          manifest = %{
            "layers" => [
              %{"digest" => layer_digest}
            ]
          }
          manifest_ref = UUID.uuid4()
          {:ok, %{location: location}} = Muster.Registry.upload_manifest(repo, manifest_ref, manifest, UUID.uuid4())
          location
        end
      end

      def upload_layer(repo) do
        digest = UUID.uuid4()
        tag = UUID.uuid4()
        %{location: location} = Muster.Registry.start_upload_chunked(repo)
        %{location: location} = Muster.Registry.chunk_upload(repo, location, {0, 3}, <<1, 2, 3>>)
        %{location: location} = Muster.Registry.chunk_upload(repo, location, {4, 7}, <<1, 2, 3>>)
        %{location: location} = Muster.Registry.complete_upload(repo, location, digest, {8, 11}, <<1, 2, 3>>)
        digest
      end
    end
  end

  setup _tags do
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
