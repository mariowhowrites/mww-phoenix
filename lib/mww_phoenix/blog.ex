defmodule MwwPhoenix.Blog do
  @moduledoc """
  The Blog context.
  """

  import Ecto.Query, warn: false
  alias MwwPhoenix.Blog.Article
  alias MwwPhoenix.{ContentBuilder, Repo}

  @doc """
  Returns the list of articles.

  ## Examples

      iex> list_articles()
      [%Article{}, ...]

  """
  def list_articles do
    Repo.all(from(a in Article))
  end

  # def list_published_articles() do
  #   Cache.all()
  #   |> Enum.sort_by(& &1.date, :desc)
  #   |> Enum.filter(&Article.should_be_published?/1)
  # end

  def list_published_articles() do
    Repo.all(from(a in Article)) |> Enum.filter(&Article.should_be_published?/1)
  end

  def get_article(slug) do
    Repo.one(
      from a in Article,
        where: a.slug == ^slug
    )
  end

  def most_recent(limit \\ 1) do
    published_keys = Application.get_env(:mww_phoenix, :notion)[:published_keys]

    dynamic_filters =
      Enum.reduce(published_keys, false, fn key, dynamic ->
        dynamic([a], ^dynamic or field(a, ^String.to_atom(key)) == true)
      end)

    Repo.all(
      from a in Article,
        where: ^dynamic_filters,
        order_by: [desc: a.date],
        limit: ^limit
    )
  end

  def get_slug(article) do
    article.title
    |> String.downcase()
    |> String.replace(",", "")
    |> String.replace(" ", "-")
  end

  # use the Article Ecto model to add each individual article to the database
  def load_articles() do
    ContentBuilder.build()
    |> Enum.each(fn article ->
      save_article(article)
    end)
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

  def site_hostname() do
    Application.get_env(:mww_phoenix, MwwPhoenixWeb.Endpoint)[:url][:host]
  end

  def save_article(article) do
    notion_id = Map.get(article, :notion_id)

    existing_record =
      Repo.one(
        from a in Article,
          where: a.notion_id == ^notion_id,
          limit: 1
      )

    cond do
      is_nil(existing_record) ->
        %Article{}
        |> Article.changeset(article)
        |> Repo.insert()

      true ->
        existing_record
        |> Article.changeset(article)
        |> Repo.update()
    end
  end

  def get_similar_articles(article) do
    Repo.all(
      from a in Article,
        where: a.category == ^article.category,
        where: a.notion_id != ^article.notion_id,
        limit: 2,
        order_by: [desc: a.date]
    )
    |> Enum.filter(&Article.should_be_published?/1)
  end
end
