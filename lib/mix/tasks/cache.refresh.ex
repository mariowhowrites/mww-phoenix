defmodule Mix.Tasks.Cache.Refresh do
  use Mix.Task

  @requirements ["app.start"]

  @impl Mix.Task
  def run(_args) do
    MwwPhoenix.Blog.load_articles()
  end
end
