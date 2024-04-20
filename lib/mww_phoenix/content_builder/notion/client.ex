defmodule MwwPhoenix.ContentBuilder.Notion.Client do
  def get_published_articles_in_database(database_id) do
    post("databases/#{database_id}/query", %{
      filter: %{
        property: "Published",
        checkbox: %{
          equals: true
        }
      }
    })
  end


  def get_page_metadata(page_id) do
    get("pages/#{page_id}")
  end

  def get_page_content(page_id) do
    get("blocks/#{page_id}/children")
  end

  def get_page_by_title(title) do
    post("search", %{query: title})
  end

  defp post(route, body) do
    api_key = get_api_key()

    Req.post(
      "https://api.notion.com/v1/#{route}",
      headers: [Authorization: "Bearer #{api_key}", "Notion-Version": "2022-06-28"],
      json: body
    )
  end

  defp get(route) do
    api_key = get_api_key()

    Req.get(
      "https://api.notion.com/v1/#{route}",
      headers: [Authorization: "Bearer #{api_key}", "Notion-Version": "2022-06-28"]
    )
  end

  defp get_api_key() do
    Application.fetch_env!(:mww_phoenix, :notion)[:api_key]
  end
end
