defmodule MwwPhoenix.Blog do
  @moduledoc """
  The Blog context.
  """

  import Ecto.Query, warn: false
  alias MwwPhoenix.ContentBuilder
  alias MwwPhoenix.Blog.Cache

  @doc """
  Returns the list of articles.

  ## Examples

      iex> list_articles()
      [%Article{}, ...]

  """
  def list_articles do
    Cache.all()
  end

  def list_published_articles() do
    Cache.all()
    |> Enum.sort_by(& &1.date, :desc)
    |> Enum.filter(&(&1.published == true))
  end

  def get_article(slug) do
    Cache.get(slug)
  end

  def most_recent() do
    Cache.most_recent()
  end

  def get_slug(article) do
    article.title
    |> String.downcase()
    |> String.replace(",", "")
    |> String.replace(" ", "-")
  end

  def rebuild_content_cache() do
    Cache.update_all(ContentBuilder.build())
  end

  def get_color_for_category(category) do
    case category do
      "Personal" -> "red"
      "Reviews" -> "green"
      "Technical" -> "indigo"
      "Magic" -> "amber"
      _ -> "green"
    end
  end
end
