defmodule MwwPhoenix.Blog.Cache do
  use GenServer
  # client fns

  def start_link(content: content) do
    GenServer.start_link(__MODULE__, content, name: __MODULE__)
  end

  def all() do
    GenServer.call(__MODULE__, {:all})
  end

  def update_all(content) do
    GenServer.cast(__MODULE__, {:update_all, content})
  end

  def most_recent() do
    GenServer.call(__MODULE__, {:most_recent})
  end

  def get(slug) do
    GenServer.call(__MODULE__, {:get, slug})
  end

  # server fns

  def init(content) do
    {:ok, content}
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

  def handle_cast({:update_all, new_articles}, _articles) do
    {:noreply, new_articles}
  end
end
