defmodule MwwPhoenixWeb.HomeLive.HomeLive do
  alias MwwPhoenix.Image
  use MwwPhoenixWeb, :live_view

  alias MwwPhoenix.Blog

  @impl true
  def mount(_params, _session, socket) do
    articles = Blog.most_recent(2)

    {
      :ok,
      socket
      |> assign(
        :articles,
        articles
      )
    }
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "All Writings")
    |> assign(:article, nil)
  end

  def article_image(article, index) do
    assigns = %{article: article, index: index}

    ~H"""
    <img
      fetchpriority={if @index < 2, do: "high", else: "low"}
      class="max-h-96 w-full object-cover"
      src={Image.get_local_path_from_storage_path(@article.image)}
      alt={@article.title}
    />
    """
  end
end
