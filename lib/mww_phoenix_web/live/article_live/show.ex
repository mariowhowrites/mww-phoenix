defmodule MwwPhoenixWeb.ArticleLive.Show do
  use MwwPhoenixWeb, :live_view

  alias MwwPhoenix.Blog.Cache

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"slug" => slug}, _, socket) do
    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:article, Cache.get(slug))}
  end

  defp page_title(:show), do: "Show Article"

  def tag_class_string(article) do
    bg_color =
      article.frontmatter["category"]
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
      srcset={srcset(@article)}
      src={static_path(@socket, @article.frontmatter["image"])}
      sizes="(max-width: 1024px) 512px, 1024vw"
      alt={@article.frontmatter["title"]}
    />
    """
  end

  defp srcset(article) do
    image_name = Path.basename(article.frontmatter["image"])

    MwwPhoenix.ResponsiveImageGenerator.dimensions()
    |> Enum.map(fn {device, width} ->
      "/images/responsive/#{device}/#{image_name} #{width}w"
    end)
    |> Enum.join(", ")
  end
end
