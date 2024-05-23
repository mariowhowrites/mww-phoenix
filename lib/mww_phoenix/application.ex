defmodule MwwPhoenix.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false
  alias MwwPhoenix.ContentBuilder

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      MwwPhoenixWeb.Telemetry,
      # Start the Ecto repository
      MwwPhoenix.Repo,
      # Start a Task Manager
      {Task.Supervisor, name: MwwPhoenix.TaskSupervisor},
      # Start the PubSub system
      {Phoenix.PubSub, name: MwwPhoenix.PubSub},
      # Start Finch
      {Finch, name: MwwPhoenix.Finch},
      # Convert images in content dir to responsive images
      # MwwPhoenix.Tasks.ConvertImages,
      # Start the Endpoint (http/https)
      MwwPhoenixWeb.Endpoint,
      # Start a worker by calling: MwwPhoenix.Worker.start_link(arg)
      # {MwwPhoenix.Worker, arg},
      {MwwPhoenix.Blog.Cache, content: fn -> ContentBuilder.build() end},

      # Start the cron job to rebuild the content cache
      {MwwPhoenix.CronJobs.RebuildContentCache, []}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: MwwPhoenix.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    MwwPhoenixWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
