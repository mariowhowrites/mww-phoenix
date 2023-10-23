defmodule MwwPhoenix.Blog do
  @moduledoc """
  The Blog context.
  """

  import Ecto.Query, warn: false
  alias MwwPhoenix.Blog.{Parser,Cache}

  @doc """
  Returns the list of articles.

  ## Examples

      iex> list_articles()
      [%Article{}, ...]

  """
  def list_articles do
    File.ls!(Application.app_dir(:mww_phoenix, "priv/content"))
    |> Enum.map(&get_article!/1)
  end

  def list_published_articles() do
    Cache.all()
    |> Enum.sort_by(& &1.frontmatter["date"], :desc)
    |> Enum.filter(&(&1.frontmatter["published"] == true))
  end

  def get_article!(slug) do
    Parser.parse_post!(slug)
  end

  def get_slug(article) do
    article.frontmatter["title"]
    |> String.downcase()
    |> String.replace(",", "")
    |> String.replace(" ", "-")
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
