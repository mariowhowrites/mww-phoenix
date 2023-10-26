defmodule MwwPhoenix.Blog.Article do
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

  def srcset(article) do
    image_name = Path.basename(article.image)

    MwwPhoenix.ResponsiveImageGenerator.dimensions()
    |> Enum.map(fn {device, width} ->
      "/images/responsive/#{device}/#{image_name} #{width}w"
    end)
    |> Enum.join(", ")
  end

  def build_meta_tags(article) do
    # this should provide a map of values that should be added to SEO header information for a given article.

    # popular seo tags are:

    # og:title
    # og:description
    # og:image
    # og:url

    # twitter:card
    # twitter:site
    # twitter:creator

  end
end
