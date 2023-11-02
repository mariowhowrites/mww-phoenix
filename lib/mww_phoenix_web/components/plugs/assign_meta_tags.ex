defmodule MwwPhoenixWeb.Plugs.AssignMetaTags do
  import Plug.Conn
  alias MwwPhoenix.Blog.{Cache, Article}

  def assign_meta_tags(conn, _opts) do
    {route, _list, _opts} = conn.private.phoenix_live_view

    assign_tags(conn, route)
  end

  defp assign_tags(conn, route) when route == MwwPhoenixWeb.ArticleLive.Show do
    article = Cache.get(conn.params["slug"])

    assign(conn, :meta_tags, Article.build_meta_tags(article))
  end

  defp assign_tags(conn, route) when route == MwwPhoenixWeb.ArticleLive.Index do
    most_recent_article = Cache.most_recent()

    assign(conn, :meta_tags, %{
      "og:title" => "mariovega.dev",
      "og:description" => "A website with words about various subjects",
      "og:image" => Article.desktop_image_url(most_recent_article),
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
