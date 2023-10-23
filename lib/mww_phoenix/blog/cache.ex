defmodule MwwPhoenix.Blog.Cache do
  use GenServer

  alias MwwPhoenix.Blog

  # client fns

  def start_link(_args) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def all() do
    GenServer.call(__MODULE__, {:all})
  end

  def get(slug) do
    GenServer.call(__MODULE__, {:get, slug})
  end

  # server fns

  def init(_state) do
    {:ok, Blog.list_articles()}
  end

  def handle_call({:all}, _caller, articles) do
    {:reply, articles, articles}
  end

  def handle_call({:get, slug}, _caller, articles) do
    article = Enum.find(articles, &(&1.frontmatter["slug"] == slug))

    {:reply, article, articles}
  end
end
