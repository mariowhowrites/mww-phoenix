defmodule MwwPhoenix.Blog.Article do
  alias MwwPhoenix.Blog
  use Ecto.Schema
  import Ecto.Changeset

  schema "articles" do
    field :content, :string
    field :title, :string

    timestamps()
  end

  @doc false
  def changeset(article, attrs) do
    article
    |> cast(attrs, [:title, :content])
    |> validate_required([:title, :content])
  end

  def full_image_url(article) do
    "https://#{Blog.site_hostname()}#{article.image}"
  end

  def desktop_image_url(article) do
    "https://#{Blog.site_hostname()}/images/responsive/desktop/#{Path.basename(article.image)}"
  end

  def mobile_image_url(article) do
    "https://#{Blog.site_hostname()}/images/responsive/mobile/#{Path.basename(article.image)}"
  end

  def full_url(article) do
    "https://#{Blog.site_hostname()}/articles/#{article.slug}"
  end

  def should_be_published?(article) do
    Enum.any?(
      Application.get_env(:mww_phoenix, :notion)[:published_keys],
      &(Map.get(article, String.to_atom(&1)) == true)
    )
  end
end
