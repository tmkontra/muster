defmodule MusterApi.RegistryController do
  use MusterApi, :controller
  require Logger

  def render_json(conn, body), do: render(conn, "index.json", body: body)

  def index(conn, _params) do
    body = %{spec_version: 1.0}
    render_json(conn, body)
  end

  def get_repo_index(conn, %{"namespace" => namespace, "name" => name} = params) do
    body = %{
      namespace: namespace,
      repo: name
    }

    render_json(conn, body)
  end

  def start_upload(conn, %{"namespace" => namespace, "name" => name} = params) do
    has_digest = Map.has_key?(params, "digest")

    type =
      case Plug.Conn.get_req_header(conn, "content-length") do
        [] -> :monolithic
        ["0"] -> :chunked
        [_length] when has_digest -> :monolithic
      end

    case MusterApi.RegistryService.start_upload(namespace, name, type) do
      %{location: location_id} ->
        location =
          MusterApi.Router.Helpers.registry_path(conn, :upload_blob, namespace, name, location_id)
        Logger.info("Sending location for new upload: #{location}")
        conn
        |> put_resp_header("Location", location)
        |> put_resp_header("Range", "bytes=0-0")
        |> put_resp_header("Docker-Upload-UUID", location_id)
        |> send_resp(202, "")
    end
  end

  def upload_blob(
        conn,
        %{"namespace" => namespace, "name" => name, "digest" => digest, "location" => location} =
          _params
      ) do
    {:ok, blob, conn} = Plug.Conn.read_body(conn)

    case MusterApi.RegistryService.upload_blob(namespace, name, location, digest, blob) do
      %{location: blob_location} ->
        location =
          MusterApi.Router.Helpers.registry_path(conn, :get_blob, namespace, name, blob_location)

        conn
        |> put_resp_header("Location", location)
        |> send_resp(201, "")
    end
  end

  defp range_from_headers(conn, blob) do
    case Plug.Conn.get_req_header(conn, "content-range") do
      [range] ->
        Logger.info("Got range from headers: #{range}")
        [range_start, range_end] = String.split(range, "-")
          |> Enum.map(fn i -> Integer.parse(i) end)
          |> Enum.map(fn {i, _} -> i end)
        {range_start, range_end}
      _ -> nil
    end
  end

  def upload_final_blob_chunk(
        conn,
        %{"namespace" => namespace, "name" => name, "location" => location, "digest" => digest} =
          _params
      ) do
    {:ok, blob, conn} = Plug.Conn.read_body(conn)
    range = range_from_headers(conn, blob)

    case MusterApi.RegistryService.upload_final_blob_chunk(
           namespace,
           name,
           location,
           digest,
           range,
           blob
         ) do
      resp -> conn |> send_resp(201, "")
    end
  end

  def upload_blob_chunk(
        conn,
        %{"namespace" => namespace, "name" => name, "location" => location} = _params
      ) do
    {:ok, blob, conn} = Plug.Conn.read_body(conn)
    range = range_from_headers(conn, blob)
    # when range is nil , upload blob chunk routes to stream upload
    case MusterApi.RegistryService.upload_blob_chunk(namespace, name, location, range, blob) do
      {:error, :illegal_chunk_sequence} ->
        conn
        |> send_resp(416, "")
      %{location: location_id, range: range} ->
        location =
          MusterApi.Router.Helpers.registry_path(conn, :upload_blob, namespace, name, location)
        conn
        |> put_resp_header("Location", location)
        |> put_resp_header("Docker-Upload-UUID", location_id)
        |> put_resp_header("Range", "0-#{range |> to_string}")
        # |> log_response()
        |> send_resp(202, "")
    end
  end

  defp log_response(conn) do
    r = conn |> to_string()
    Logger.debug("Response: #{r}")
    conn
  end

  def upload_manifest(
        %{:body_params => manifest} = conn,
        %{"namespace" => namespace, "name" => name, "reference" => reference} = _params
      ) do
    digests = conn.assigns.digests

    case MusterApi.RegistryService.upload_manifest(namespace, name, reference, manifest, digests) do
      {:ok, %{location: location}} ->
        location =
          MusterApi.Router.Helpers.registry_path(conn, :get_manifest, namespace, name, location)

        conn
        |> put_resp_header("Location", location)
        |> put_resp_header("Manifest-Digest", digests)
        |> send_resp(201, "")

      error ->
        Logger.error("Unable to upload manifest: #{error}")
        conn |> send_resp(400, "")
    end
  end

  def get_blob(conn, %{"namespace" => namespace, "name" => name, "digest" => digest} = _params) do
    case MusterApi.RegistryService.get_blob(namespace, name, digest) do
      {:error, :not_found} -> conn |> send_resp(404, "")
      {:ok, resp} -> conn |> send_resp(200, resp)
    end
  end

  def blob_exists?(
        conn,
        %{"namespace" => namespace, "name" => name, "digest" => digest} = _params
      ) do
    Logger.debug("Checking blob exists? #{digest}")
    case MusterApi.RegistryService.blob_exists?(namespace, name, digest) do
      false -> conn |> not_found()
      true -> conn |> send_resp(200, "")
    end
  end

  def get_manifest(
        conn,
        %{"namespace" => namespace, "name" => name, "reference" => reference} = _params
      ) do
    case MusterApi.RegistryService.get_manifest(namespace, name, reference) do
      {:error, :not_found} -> conn |> not_found
      {:ok, manifest} -> render_json(conn, %{manifest: manifest})
    end
  end

  def manifest_exists?(
        conn,
        %{"namespace" => namespace, "name" => name, "reference" => reference} = _params
      ) do
    case MusterApi.RegistryService.manifest_exists?(namespace, name, reference) do
      false -> conn |> not_found
      true -> conn |> render_json(%{})
    end
  end

  def list_tags(conn, %{"namespace" => namespace, "name" => name} = params) do
    {:ok, n} = Map.get(params, "n") |> optional_int()
    last = Map.get(params, "last")

    case MusterApi.RegistryService.list_tags(namespace, name, n, last) do
      tags -> conn |> render("tags.json", name: name, tags: tags)
    end
  end

  defp optional_int(optional_param) do
    case optional_param do
      n when is_binary(n) ->
        case Integer.parse(n) do
          :error -> {:error, nil}
          {int, _} -> {:ok, int}
        end

      nil ->
        {:ok, nil}
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
