defmodule MusterApi.RegistryControllerTest do
  use MusterApi.ConnCase

  test "GET /v2/", %{conn: conn} do
    conn = get(conn, "/v2/")
    %{"spec_version" => _} = json_response(conn, 200)
  end

  test "GET /v2/<namespace>/<name>/", %{conn: conn} do
    namespace = random_string(16)
    name = random_string(22)
    conn = get(conn, "/v2/#{namespace}/#{name}/")

    %{
      "namespace" => namespace_resp,
      "repo" => name_resp
    } = json_response(conn, 200)

    assert namespace_resp == namespace
    assert name_resp = name
  end

  test "GET /v2/<name>/blobs/<digest>", %{conn: conn} do
    namespace = random_string(16)
    name = random_string(22)
    digest = random_string(128)
    conn = get(conn, "/v2/#{namespace}/#{name}/blobs/#{digest}")
  end

  test "/v2/<name>/manifests/<reference>", %{conn: conn} do
    namespace = random_string(16)
    name = random_string(22)
    reference = random_string(18)
    conn = get(conn, "/v2/#{namespace}/#{name}/manifests/#{reference}")
  end

  test "HEAD request to manifest path (tag) should yield 200 response", %{conn: conn} do
    namespace = random_string(16)
    name = random_string(22)
    reference = upload_manifest(namespace, name)
    conn = head(conn, "/v2/#{namespace}/#{name}/manifests/#{reference}")
    _ = response(conn, 200)
  end
end
