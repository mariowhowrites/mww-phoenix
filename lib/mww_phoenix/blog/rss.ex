defmodule MwwPhoenix.Blog.RSS do
  alias MwwPhoenix.Blog

  import XmlBuilder

  @doc """
  Return all articles as RSS.

  Uses the xml_builder library to format blog posts according to the RSS 2.0 specification.
  """
  def all() do
    articles = Blog.list_published_articles()

    xml = document(:rss, %{version: "2.0"}, [
      element(:channel, %{}, [
        element(:title, %{}, "mariovega.dev"),
        element(:link, %{}, "https://mariovega.dev"),
        element(:description, %{}, "mariovega.dev is a blog about software development, magic, and life."),
        element(:language, %{}, "en-us"),
        element(:pubDate, %{}, DateTime.utc_now() |> to_rfc822()),
        element(:lastBuildDate, %{}, DateTime.utc_now |> to_rfc822()),
        element(:generator, %{}, "Phoenix LiveView"),
        element(:docs, %{}, "https://validator.w3.org/feed/docs/rss2.html"),
        element(:ttl, %{}, 1440),
        articles |> Enum.map(fn article ->
          # we need to add time data to make the date RFC822 compliant
          {:ok, published_date, 0} = DateTime.from_iso8601("#{article.date}T13:30:00.0Z")

          element(:item, %{}, [
            element(:title, %{}, article.title),
            element(:link, %{}, "https://mariovega.dev/articles/#{Blog.get_slug(article)}"),
            element(:description, %{}, {:cdata, article.content}),
            element(:pubDate, %{}, published_date |> to_rfc822()),
            element(:guid, %{}, "https://mariovega.dev/articles/#{Blog.get_slug(article)}")
          ])
        end)
      ])
    ]) |> generate

    {:ok, xml}
  end

  defp to_rfc822(date) do
    date |> Calendar.strftime("%a, %d %b %Y %H:%M:%S %z")
  end
end
