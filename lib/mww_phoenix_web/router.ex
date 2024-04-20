defmodule MwwPhoenixWeb.Router do
  use MwwPhoenixWeb, :router
  import MwwPhoenixWeb.Plugs.AssignMetaTags

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {MwwPhoenixWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", MwwPhoenixWeb do
    pipe_through [:browser, :assign_meta_tags]

    live "/", ArticleLive.Index, :index
    live "/articles/:slug", ArticleLive.Show, :show

    get "/feed", RssController, :all

    get "/dev/_content_cache", ContentCacheController, :get
  end

  # Other scopes may use custom stacks.
  # scope "/api", MwwPhoenixWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:mww_phoenix, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: MwwPhoenixWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
