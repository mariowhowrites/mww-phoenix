defmodule MwwPhoenix.CronJobs.RebuildContentCache do
  use GenServer

  @moduledoc """
  A GenServer that rebuilds the content cache every 24 hours.
  This ensures current content without needing to manually deploy after publishing new articles.
  """

  alias MwwPhoenix.Blog

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{})
  end

  def init(state) do
    schedule_work()

    {:ok, state}
  end

  def handle_info(:work, state) do
    Blog.load_articles()

    schedule_work()

    {:noreply, state}
  end

  defp schedule_work() do
    Process.send_after(self(), :work, 24 * 60 * 60 * 1000)
  end
end
