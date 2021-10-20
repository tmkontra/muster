defmodule Muster.RepositoryCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      def random_string(length), do: s = for _ <- 1..length, into: "", do: <<Enum.random('0123456789abcdef')>>

      def upload_manifest(repo, manifest) do
        manifest_ref = UUID.uuid4()
        {:ok, %{location: location}} = Muster.Repository.upload_manifest(repo, manifest_ref, manifest, UUID.uuid4())
        location
      end

      def upload_manifest(repo) do
        layer_digest = upload_layer(repo)
        manifest = %{
          "layers" => [
            %{"digest" => layer_digest}
          ]
        }
        upload_manifest(repo, manifest)
      end

      def upload_layer(repo) do
        digest = UUID.uuid4()
        tag = UUID.uuid4()
        %{location: location} = Muster.Repository.start_upload_chunked(repo)
        %{location: location} = Muster.Repository.chunk_upload(repo, location, {0, 3}, <<1, 2, 3>>)
        %{location: location} = Muster.Repository.chunk_upload(repo, location, {4, 7}, <<1, 2, 3>>)
        %{location: location} = Muster.Repository.complete_upload(repo, location, digest, {8, 11}, <<1, 2, 3>>)
        digest
      end
    end
  end
end
