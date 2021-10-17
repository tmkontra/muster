defmodule MusterApi.RegistryService do
  use MusterApi, :service

  def get_blob(namespace, name, digest) do
    repo = namespace<>name
    with_repo repo do
      Muster.Registry.get_layer(repo, digest)
    end
  end
end
