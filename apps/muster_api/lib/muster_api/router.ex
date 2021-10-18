defmodule MusterApi.Router do
  use MusterApi, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/v2", MusterApi do
    pipe_through :api

    get "/", RegistryController, :index

    scope "/:namespace/:name" do
      get "/", RegistryController, :get_repo_index

      post "/blobs/uploads", RegistryController, :start_upload
      put "/blobs/uploads/:location", RegistryController, :upload_blob
      patch "/blobs/uploads/:location", RegistryController, :upload_blob_chunk
      put "/manifests/:reference", RegistryController, :upload_manifest

      get "/blobs/:digest", RegistryController, :get_blob
      head "/blobs/:digest", RegistryController, :blob_exists?

      head "/manifests/:reference", RegistryController, :manifest_exists?
      get "/manifests/:reference", RegistryController, :get_manifest

      get "/tags/list", RegistryController, :list_tags

      delete "/*any_match", RegistryController, :method_not_allowed

      get "/*any_match", RegistryController, :default_route
    end
  end

  scope "/", MusterApi do
    pipe_through :browser

    get "/", PageController, :index
  end

  # Other scopes may use custom stacks.
  # scope "/api", MusterApi do
  #   pipe_through :api
  # end

  # Enables LiveDashboard only for development
  #
  # If you want to use the LiveDashboard in production, you should put
  # it behind authentication and allow only admins to access it.
  # If your application does not have an admins-only section yet,
  # you can use Plug.BasicAuth to set up some basic authentication
  # as long as you are also using SSL (which you should anyway).
  if Mix.env() in [:dev, :test] do
    import Phoenix.LiveDashboard.Router

    scope "/" do
      pipe_through :browser
      live_dashboard "/dashboard", metrics: MusterApi.Telemetry
    end
  end
end
