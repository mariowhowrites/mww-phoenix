defmodule MwwPhoenixWeb.Plugs.AssignMetaTags do
  import Plug.Conn
  alias MwwPhoenix.Blog.{Cache, Article}

  def assign_meta_tags(conn, _opts) do
    if Map.has_key?(conn.private, :phoenix_live_view) do
      {route, _list, _opts} = conn.private.phoenix_live_view

      assign_tags(conn, route)
    else
      conn
    end
  end

  defp assign_tags(conn, route) when route == MwwPhoenixWeb.ArticleLive.Show do
    article = Cache.get(conn.params["slug"])

    assign(conn, :meta_tags, %{
      "og:title" => article.title,
      "og:description" => article.description,
      "og:image" => article.image,
      "og:url" => Article.full_url(article),
      "twitter:card" => "summary_large_image",
      "twitter:creator" => "@mariowhowrites"
    })
  end

  defp assign_tags(conn, route) when route == MwwPhoenixWeb.ArticleLive.Index do
    most_recent_article = Cache.most_recent()

    assign(conn, :meta_tags, %{
      "og:title" => "mariovega.dev",
      "og:description" => "A website with words about various subjects",
      "og:image" => most_recent_article.image,
      "og:url" => "https://mariovega.dev",
      "twitter:card" => "summary",
      "twitter:creator" => "@mariowhowrites"
    })
  end

  # default case, return nothing
  defp assign_tags(conn, _route) do
    assign(conn, :meta_tags, [])
  end
end