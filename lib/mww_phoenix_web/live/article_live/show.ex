defmodule MwwPhoenixWeb.ArticleLive.Show do
  use MwwPhoenixWeb, :live_view

  alias MwwPhoenix.Blog
  alias MwwPhoenix.Blog.Article

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    {:ok, socket |> assign(:slug, slug)}
  end

  @impl true
  def handle_params(_params, _, socket) do
    article = Blog.get_article(socket.assigns.slug)

    {:noreply,
     socket
     |> assign(:page_title, article.title)
     |> assign(:article, article)
     }
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
end
