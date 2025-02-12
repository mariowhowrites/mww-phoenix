defmodule MwwPhoenix.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false
  alias MwwPhoenix.Blog
  require Logger

  use Application

  @impl true
  def start(_type, _args) do
    verify_volume()

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
      # Start the Endpoint (http/https)
      MwwPhoenixWeb.Endpoint,
      # Start a worker by calling: MwwPhoenix.Worker.start_link(arg)
      # {MwwPhoenix.Worker, arg},

      # Start the cron job to rebuild the content cache
      {MwwPhoenix.CronJobs.RebuildContentCache, []},
      {Task, fn -> Blog.load_articles() end}
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

  def verify_volume do
    test_path = "priv/static/images/test.txt"

    case File.write(test_path, "test #{DateTime.utc_now()}") do
      :ok ->
        Logger.info("Successfully wrote to volume at #{test_path}")

      {:error, reason} ->
        Logger.error("Failed to write to volume: #{inspect(reason)}")
    end
  end
end
