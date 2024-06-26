defmodule MwwPhoenix.ContentBuilder.Notion do
  use MwwPhoenixWeb, :controller
  alias MwwPhoenix.ContentBuilder.Notion.Renderer
  alias Phoenix.LiveView.Rendered
  alias MwwPhoenix.ContentBuilder.Notion.{Client, Parser, Interpreter}

  def build() do
    database_id = Application.fetch_env!(:mww_phoenix, :notion)[:database_id]

    {:ok, res} = Client.get_published_articles_in_database(database_id)

    Enum.map(res.body["results"], &parse_article!/1)
  end

  def new_build() do
    database_id = Application.fetch_env!(:mww_phoenix, :notion)[:database_id]

    {:ok, res} = Client.get_published_articles_in_database(database_id)

    res.body["results"]
    |> Enum.map(Interpreter.interpret_article!/1)
    |> Enum.map(Renderer.render_article!/1)
  end

  defp parse_article!(%{"id" => id}) do
    {:ok, metadata} = Client.get_page_metadata(id)
    {:ok, page_content} = Client.get_children(id)

    build_article_content(metadata, page_content.body["results"])
  end

  def build_article_content(metadata, all_blocks) do
    parsed_metadata = Parser.parse_metadata(metadata)

    if parsed_metadata.title == "Notion Test Article" do
      File.write!("priv/stubs/notion.json", Jason.encode!(all_blocks))
    end

    Map.put(
      parsed_metadata,
      :content,
      Parser.parse_all_blocks!(all_blocks, parsed_metadata)
    )
  end
end
