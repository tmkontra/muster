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
    has_digest = Map.has_key?(params, "digest")
    type = case Plug.Conn.get_req_header(conn, "content-length") do
      [] -> :monolithic
      ["0"] -> :chunked
      [_length] when has_digest -> :monolithic
    end
    case MusterApi.RegistryService.start_upload(namespace, name, type) do
      %{location: location} = resp ->
        location = MusterApi.Router.Helpers.registry_path(conn, :upload_blob, namespace, name, location)
        conn
        |> put_status(202)
        |> put_resp_header("Location", location)
        |> render_json(%{"type" => type})
    end
  end

  def upload_blob(conn, %{"namespace" => namespace, "name" => name, "digest" => digest, "location" => location} = _params) do
    {:ok, blob, conn} = Plug.Conn.read_body(conn)
    case MusterApi.RegistryService.upload_blob(namespace, name, location, digest, blob) do
      %{location: blob_location} ->
        location = MusterApi.Router.Helpers.registry_path(conn, :get_blob, namespace, name, blob_location)
        conn
        |> put_resp_header("Location", location)
        |> send_resp(201, "")
    end
  end

  def upload_final_blob_chunk(
    conn,
    %{"namespace" => namespace, "name" => name, "location" => location, "digest" => digest} = _params) do
      {:ok, blob, conn} = Plug.Conn.read_body(conn)
      [range] = Plug.Conn.get_req_header(conn, "content-range")
      [range_start | range_end] = String.split(range, "-") |> Enum.map(fn i -> Integer.parse(i) end) |> Enum.map(fn {i, _} -> i end)
      range = { range_start, range_end }
      case MusterApi.RegistryService.upload_final_blob_chunk(namespace, name, location, digest, range, blob) do
        resp -> conn |> send_resp(201, "")
      end
  end

  def upload_blob_chunk(
    conn,
    %{"namespace" => namespace, "name" => name, "location" => location} = _params) do
    {:ok, blob, conn} = Plug.Conn.read_body(conn)
    [range] = Plug.Conn.get_req_header(conn, "content-range")
    [range_start | range_end] = String.split(range, "-") |> Enum.map(fn i -> Integer.parse(i) end) |> Enum.map(fn {i, _} -> i end)
    range = { range_start, range_end }
    case MusterApi.RegistryService.upload_blob_chunk(namespace, name, location, range, blob) do
      {:error, :illegal_chunk_sequence} ->
        conn
        |> send_resp(416, "")
      %{location: _blob_location} ->
        location = MusterApi.Router.Helpers.registry_path(conn, :upload_blob, namespace, name, location)
        conn
        |> put_resp_header("Location", location)
        |> send_resp(202, "")
    end
  end

  def upload_manifest(conn, %{"namespace" => namespace, "name" => name, "reference" => reference} = _params) do
    resp = MusterApi.RegistryService.upload_manifest(namespace, name, reference, %{})
    render_json(conn, resp)
  end

  def get_blob(conn, %{"namespace" => namespace, "name" => name, "digest" => digest} = _params) do
    case MusterApi.RegistryService.get_blob(namespace, name, digest) do
      {:error, :not_found} -> conn |> send_resp(404, "")
      {:ok, resp} -> conn |> send_resp(200, resp)
    end
  end

  def blob_exists?(conn, %{"namespace" => namespace, "name" => name, "digest" => digest} = _params) do
    case MusterApi.RegistryService.blob_exists?(namespace, name, digest) do
      false -> conn |> not_found
      true -> conn |> render_json(%{})
    end
  end

  def get_manifest(conn, %{"namespace" => namespace, "name" => name, "reference" => reference} = _params) do
    case MusterApi.RegistryService.get_manifest(namespace, name, reference) do
      {:error, :not_found} -> conn |> not_found
      manifest -> render_json(conn, %{manifest: manifest})
    end
  end

  def manifest_exists?(conn, %{"namespace" => namespace, "name" => name, "reference" => reference} = _params) do
    case MusterApi.RegistryService.manifest_exists?(namespace, name, reference) do
      false -> conn |> not_found
      true -> conn |> render_json(%{})
    end
  end

  def default_route(conn, %{"any_match" => _matched}) do
    conn |> send_resp(501, "")
  end

  def not_found(conn) do
    conn |> send_resp(404, "")
  end

  def method_not_allowed(conn, _) do
    conn |> send_resp(405, "")
  end
end
