defmodule Muster.Storage do

  # Application.compile_env!(:muster, :storage_root)
  @storage_root Application.fetch_env!(:muster, :storage_root)

  def storage_root(), do: @storage_root

  # Storage Driver
  def get_blob(namespace, name, digest) do
    filepath(namespace, name, digest)
    |> File.read()
    |> case do
      {:ok, blob} -> {:ok, blob}
      {:error, :enomem} -> {:error, :ephemeral}
      {:error, _cause} -> {:error, :not_found}
    end
  end

  def write_blob(namespace, name, digest, blob) do
    Path.join([@storage_root, namespace, name]) |> File.mkdir_p()
    filepath(namespace, name, digest)
    |> File.write(blob)
    |> case do
      {:error, :enomemt} -> {:error, :ephemeral}
      {:error, :enoent} -> raise "storage error: enoent"
      other -> other
    end
  end

  defp filepath(namespace, name, digest), do: [@storage_root, namespace, name, digest] |> Path.join()
end
