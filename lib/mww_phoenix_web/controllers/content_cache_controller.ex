defmodule MwwPhoenixWeb.ContentCacheController do
  use MwwPhoenixWeb, :controller

  alias MwwPhoenix.Blog

  def get(conn, _assigns) do
    # Redirect the user to their previous URL location
    conn = redirect(conn, to: get_previous_url(conn))

    # Rebuild the content cache asynchronously
    Task.start(fn -> Blog.load_articles() end)

    conn
  end

  defp get_previous_url(conn) do
    case get_req_header(conn, "referer") do
      [] -> "/"
      [referer] -> referer |> URI.parse() |> Map.get(:path)
    end
  end
end
