defmodule MwwPhoenix.ContentBuilder.Notion do
  use MwwPhoenixWeb, :controller
  alias MwwPhoenix.Image
  alias MwwPhoenix.ContentBuilder.Notion.{Client, Parser}

  def build() do
    database_id = Application.fetch_env!(:mww_phoenix, :notion)[:database_id]

    {:ok, res} = Client.get_published_articles_in_database(database_id)

    Enum.map(res.body["results"], &parse_article!/1)
  end

  defp parse_article!(page) do
    {:ok, metadata} = Client.get_page_metadata(page["id"])
    {:ok, res} = Client.get_page_content(page["id"]  )

    build_article_content(metadata, res.body["results"])
  end

  def build_article_content(metadata, all_blocks) do
    parsed_metadata = Parser.parse_metadata(metadata)

    Map.put(
      parsed_metadata,
      :content,
      Parser.parse_all_blocks!(all_blocks, parsed_metadata)
    )
  end
end
