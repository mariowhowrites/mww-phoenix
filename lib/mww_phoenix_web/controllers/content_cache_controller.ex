defmodule MwwPhoenixWeb.ContentCacheController do
  use MwwPhoenixWeb, :controller

  alias MwwPhoenix.Blog

  def get(conn, _assigns) do
    # Rebuild the content cache here
    Blog.rebuild_content_cache()

    # Redirect the user to their previous URL location
    redirect(conn, to: get_previous_url(conn))
  end

  defp get_previous_url(conn) do
    case get_req_header(conn, "referer") do
      [] -> "/"
      [referer] -> referer |> URI.parse() |> Map.get(:path)
    end
  end
end
