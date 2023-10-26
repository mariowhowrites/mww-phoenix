defmodule MwwPhoenixWeb.ArticleLive.Show do
  use MwwPhoenixWeb, :live_view

  alias MwwPhoenix.Blog.{Cache,Article}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"slug" => slug}, _, socket) do
    article = Cache.get(slug)

    {:noreply,
     socket
     |> assign(:page_title, article.title)
     |> assign(:article, article)}
  end

  def tag_class_string(article) do
    bg_color =
      article.category
      |> get_background_color()

    "text-sm font-medium text-white self-start #{bg_color} rounded-lg px-2 mr-3"
  end

  defp get_background_color(category) do
    case category do
      "Personal" -> "bg-red-600"
      "Reviews" -> "bg-green-600"
      "Technical" -> "bg-indigo-600"
      "Magic" -> "bg-amber-600"
    end
  end

  def article_image(assigns) do
    ~H"""
    <img
      class="h-124 w-full object-cover mb-8"
      srcset={Article.srcset(@article)}
      src={static_path(@socket, @article.image)}
      sizes="(max-width: 1024px) 512px, 1024vw"
      alt={@article.title}
    />
    """
  end
end
