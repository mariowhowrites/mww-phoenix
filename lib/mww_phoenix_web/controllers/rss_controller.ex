defmodule MwwPhoenixWeb.RssController do
  use MwwPhoenixWeb, :controller

  alias MwwPhoenix.Blog.RSS

  @doc """
  Returns all articles in RSS format.
  """
  def all(conn, _assigns) do
    {:ok, xml} = RSS.all()

    conn |> put_resp_content_type("application/rss+xml") |> send_resp(200, xml)
  end
end
