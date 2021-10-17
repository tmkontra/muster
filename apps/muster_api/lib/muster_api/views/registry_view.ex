defmodule MusterApi.RegistryView do
  use MusterApi, :view

  def render("index.json", %{body: body}) do
    body
  end
end
