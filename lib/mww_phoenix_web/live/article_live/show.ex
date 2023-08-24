defmodule MwwPhoenixWeb.ArticleLive.Show do
  use MwwPhoenixWeb, :live_view

  alias MwwPhoenix.Blog

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"slug" => slug}, _, socket) do
    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:article, Blog.get_article!(slug))}
  end

  defp page_title(:show), do: "Show Article"

  def tag_class_string(article) do
    bg_color = article.frontmatter["category"]
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
