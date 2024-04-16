defmodule MwwPhoenix.ContentBuilder.Notion do
  alias MwwPhoenix.ContentBuilder.Notion.{Client, Parser}
  def build() do
    database_id = Application.fetch_env!(:mww_phoenix, :notion)[:database_id]

    {:ok, res} = Client.get_published_articles_in_database(database_id)

    Enum.map(res.body["results"], &parse_post!/1)
  end

  defp parse_post!(page) do
    {:ok, metadata} = Client.get_page_metadata(page["id"])
    {:ok, res} = Client.get_page_content(page["id"])

    build_article_content(metadata, res.body["results"])
  end

  def build_article_content(metadata, all_blocks) do
    {:ok, parsed_metadata} = Parser.parse_metadata(metadata)
    Map.put(
      parsed_metadata,
      :content,
      Parser.parse_all_blocks!(all_blocks)
    )
  end
end
