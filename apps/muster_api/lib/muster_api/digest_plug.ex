defmodule MusterApi.Plug.DigestPlug do
  def read_body(conn, opts) do
    {:ok, body, conn} = Plug.Conn.read_body(conn, [length: 500000000])
    digests = digest_content(body)
    conn = update_in(conn.assigns[:digests], fn _ -> digests end)
    {:ok, body, conn}
  end

  def digest_content(body) do
    :crypto.hash(:sha256, body)
    |> Base.encode16(case: :lower)
    |> (fn d -> "sha256:" <> d end).()
  end
end
