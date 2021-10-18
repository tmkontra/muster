defmodule MusterApi.RegistryView do
  use MusterApi, :view

  def render("index.json", %{body: body}) do
    body
  end

   def render("tags.json", %{name: name, tags: tags}) when is_binary(name) and is_list(tags) do
    %{
      "name" => name,
      "tags" => tags
    }
  end
end
