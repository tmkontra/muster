defmodule MusterApi.RegistryController do
  use MusterApi, :controller

  def render_json(conn, body), do: render(conn, "index.json", body: body)

  def index(conn, _params) do
    body = %{spec_version: 1.0}
    render_json(conn, body)
  end

  def get_repo_index(conn, %{"namespace" => namespace, "name" => name} = params) do
    body = %{
      namespace: namespace,
      repo: name,
    }
    render_json(conn, body)
  end

  def start_upload(conn, %{"namespace" => namespace, "name" => name} = params) do
    conn |> send_resp(202, "")
  end
  def upload_manifest(conn, %{"namespace" => namespace, "name" => name, "reference" => reference} = params) do
    conn |> send_resp(202, "")
  end

  def get_blob(conn, %{"namespace" => namespace, "name" => name, "digest" => digest} = params) do
    case MusterApi.RegistryService.get_blob(namespace, name, digest) do
      {:error, :not_found} -> conn |> send_resp(404, "")
      {:ok, resp} -> render_json(conn, resp)
    end
  end

  def blob_exists?(conn, %{"namespace" => namespace, "name" => name, "digest" => digest} = params) do
    case Muster.Registry.blob_exists?(namespace <> name, digest) do
      false -> conn |> not_found
      true -> conn |> render_json(%{})
    end
  end

  def get_manifest(conn, %{"namespace" => namespace, "name" => name, "reference" => reference} = params) do
    case Muster.Registry.get_manifest(namespace <> name, reference) do
      {:error, :not_found} -> conn |> not_found
      manifest -> render_json(conn, %{manifest: manifest})
    end
  end

  def manifest_exists?(conn, %{"namespace" => namespace, "name" => name, "reference" => reference} = params) do
    case Muster.Registry.manifest_exists?(namespace <> name, reference) do
      false -> conn |> not_found
      true -> conn |> render_json(%{})
    end
  end

  def default_route(conn, %{"any_match" => matched}) do
    conn |> send_resp(501, "")
  end

  def not_found(conn) do
    conn |> send_resp(404, "")
  end

  def method_not_allowed(conn, _) do
    conn |> send_resp(405, "")
  end
end
