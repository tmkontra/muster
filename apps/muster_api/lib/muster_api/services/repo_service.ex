defmodule MusterApi.RepoService do
  def create_repo(repo) do
    # TODO: get repo state from db
    Muster.Registry.start_repo(repo)
  end

  def with_repo(repo, func) when is_function(func) do
    via = repo |> Muster.Registry.repo_via()
    try do
      func.(via)
    catch
      :exit, {:noproc, _} ->
        create_repo(repo)
        func.(via)
    end
  end
end
