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

  def most_recent() do
    GenServer.call(__MODULE__, {:most_recent})
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

  def handle_call({:most_recent}, _caller, articles) do
    article = articles
      |> Enum.filter(& &1.published == true)
      |> Enum.sort_by(& &1.date, :desc)
      |> List.first()

    {:reply, article, articles}
  end

  def handle_call({:get, slug}, _caller, articles) do
    article = Enum.find(articles, &(&1.slug == slug))

    {:reply, article, articles}
  end
end
