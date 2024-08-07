defmodule MwwPhoenix.Blog.Article do
  alias MwwPhoenix.Blog
  use Ecto.Schema
  import Ecto.Changeset

  schema "articles" do
    field :content, :string
    field :title, :string
    field :description, :string
    field :category, :string
    field :slug, :string
    field :image, :string
    field :published, :boolean
    field :published_dev, :boolean
    field :date, :string
    field :tags, {:array, :string}
    field :notion_id, :string

    timestamps()
  end

  @doc false
  def changeset(article, attrs) do
    article
    |> cast(Map.from_struct(attrs), [
      :title,
      :content,
      :description,
      :category,
      :slug,
      :image,
      :published,
      :published_dev,
      :date,
      :tags,
      :notion_id
    ])
    |> validate_required([
      :title,
      :content,
      :description,
      :category,
      :slug,
      :image,
      :published,
      :published_dev,
      :date,
      :tags,
      :notion_id
    ])
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
