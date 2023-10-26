defmodule MwwPhoenixWeb.ArticleLive.Index do
  use MwwPhoenixWeb, :live_view

  alias MwwPhoenix.Blog
  alias MwwPhoenix.Blog.Article

  @impl true
  def mount(_params, _session, socket) do
    articles = Blog.list_published_articles()
    categories = Enum.map(articles, & &1.category) |> Enum.uniq()

    {
      :ok,
      socket
      |> assign(
        :articles,
        articles
      )
      |> assign(
        :categories,
        categories
      )
      |> assign(
        :selected_category,
        nil
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

  def handle_event("toggle_selected_category", %{"category" => category}, socket) do
    new_selected_category =
      if socket.assigns.selected_category != category, do: category, else: nil

    new_articles =
      if new_selected_category != nil do
        Enum.filter(Blog.list_published_articles(), &(&1.category == category))
      else
        Blog.list_published_articles()
      end

    {
      :noreply,
      socket
      |> assign(
        :selected_category,
        new_selected_category
      )
      |> assign(
        :articles,
        new_articles
      )
    }
  end

  def blog_index_category_button(assigns) do
    color = Blog.get_color_for_category(assigns.category)

    color_map = %{
      red: %{
        selected: "bg-red-600 text-white border-red-400",
        nonselected: "bg-red-900 text-red-400 hover:bg-red-700 hover:text-white border-red-400"
      },
      indigo: %{
        selected: "bg-indigo-400 text-white border-indigo-400",
        nonselected:
          "bg-indigo-900 text-indigo-400 hover:bg-indigo-700 hover:text-white border-indigo-400"
      },
      green: %{
        selected: "bg-green-400 text-white border-green-400",
        nonselected:
          "bg-green-900 text-green-400 hover:bg-green-700 hover:text-white border-green-400"
      },
      amber: %{
        selected: "bg-amber-400 text-white border-amber-400",
        nonselected:
          "bg-amber-900 text-amber-400 hover:bg-amber-700 hover:text-white border-amber-400"
      }
    }

    color_classes = Map.get(color_map, String.to_atom(color))

    assigns =
      assign(
        assigns,
        :button_classes,
        if(assigns.category == assigns.selected_category,
          do: color_classes.selected,
          else: color_classes.nonselected
        )
      )

    ~H"""
    <button
      class={@button_classes <> " border shadow-xl text-xl md:text-3xl px-4 rounded-sm"}
      phx-click="toggle_selected_category"
      phx-value-category={@category}
    >
      <%= @category %>
    </button>
    """
  end

  def article_image(article, index) do
    assigns = %{article: article, index: index}

    ~H"""
    <img
      fetchpriority={if @index < 2, do: "high", else: "low"}
      class="max-h-96 w-full object-cover"
      srcset={srcset(@article)}
      sizes="(max-width: 1024px) 512px, 1024px"
      alt={@article.title}
    />
    """
  end

  defp srcset(article) do
    image_name = Path.basename(article.image)

    MwwPhoenix.ResponsiveImageGenerator.dimensions()
    |> Enum.map(fn {device, width} ->
      "/images/responsive/#{device}/#{image_name} #{width}w"
    end)
    |> Enum.join(", ")
  end
end
