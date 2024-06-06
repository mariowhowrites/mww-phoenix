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

  defp site_hostname() do
    Application.get_env(:mww_phoenix, MwwPhoenixWeb.Endpoint)[:url][:host]
  end

  def full_image_url(article) do
    "https://#{site_hostname()}#{article.image}"
  end

  def desktop_image_url(article) do
    "https://#{site_hostname()}/images/responsive/desktop/#{Path.basename(article.image)}"
  end

  def mobile_image_url(article) do
    "https://#{site_hostname()}/images/responsive/mobile/#{Path.basename(article.image)}"
  end

  def full_url(article) do
    "https://#{site_hostname()}/articles/#{article.slug}"
  end

  def should_be_published?(article) do
    Enum.any?(
      Application.get_env(:mww_phoenix, :notion)[:published_keys],
      &(Map.get(article, String.to_atom(&1)) == true)
    )
  end
end
