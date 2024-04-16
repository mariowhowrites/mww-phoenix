defmodule MwwPhoenix.ContentBuilder.Notion.Parser do
  def parse_metadata(metadata) do
    {
      :ok,
      %{
        category: Enum.at(metadata.body["properties"]["Category"]["multi_select"], 0)["name"],
        description:
          Enum.at(metadata.body["properties"]["Description"]["rich_text"], 0)["text"]["content"],
        title: Enum.at(metadata.body["properties"]["Title"]["title"], 0)["text"]["content"],
        slug: Enum.at(metadata.body["properties"]["Slug"]["rich_text"], 0)["text"]["content"],
        date: metadata.body["properties"]["Published On"]["date"]["start"],
        published: metadata.body["properties"]["Published"]["checkbox"],
        image: Enum.at(metadata.body["properties"]["Image"]["files"], 0)["file"]["url"],
        tags: []
      }
    }
  end
  def parse_all_blocks!(all_blocks) do
    all_blocks
      |> Enum.with_index()
      |> Enum.map(fn {block, index} -> parse_block!(block, index, all_blocks) end)
      |> Enum.join("")
  end

  def parse_block!(block, index, all_blocks) do
    case block["type"] do
      "paragraph" -> parse_block!(:paragraph, block)
      "heading_1" -> parse_block!(:heading_1, block)
      "heading_2" -> parse_block!(:heading_2, block)
      "heading_3" -> parse_block!(:heading_3, block)
      "code" -> parse_block!(:code, block)
      "image" -> parse_block!(:image, block)
      "child_page" -> parse_block!(:child_page, block)
      "bulleted_list_item" -> parse_block!(:bulleted_list_item, block, index, all_blocks)
      "numbered_list_item" -> parse_block!(:numbered_list_item, block, index, all_blocks)
      "divider" -> parse_block!(:divider, block)
    end
  end

  def parse_block!(:paragraph, block) do
    (["<p>"] ++ Enum.map(block["paragraph"]["rich_text"], &parse_rich_text/1) ++ ["</p>"])
    |> Enum.join("")
  end

  def parse_block!(:heading_1, block) do
    "<h1>#{Enum.at(block["heading_1"]["rich_text"], 0)["plain_text"]}</h1>"
  end

  def parse_block!(:heading_2, block) do
    "<h2>#{Enum.at(block["heading_2"]["rich_text"], 0)["plain_text"]}</h2>"
  end

  def parse_block!(:heading_3, block) do
    "<h3>#{Enum.at(block["heading_3"]["rich_text"], 0)["plain_text"]}</h3>"
  end

  def parse_block!(:code, block) do
    code = HtmlEntities.encode(Enum.at(block["code"]["rich_text"], 0)["plain_text"])

    "<pre><code class=\"hljs language-#{block["code"]["language"]}\">#{code}</code></pre>"
  end

  def parse_block!(:image, block) do
    "<img src=\"#{block["image"]["file"]["url"]}\" alt=\"#{Enum.at(block["image"]["caption"], 0)["plain_text"]}\">"
  end

  def parse_block!(:child_page, _block) do
    # IO.inspect(block)
    ""
  end

  def parse_block!(:divider, _block) do
    "<hr>"
  end

  def parse_block!(:bulleted_list_item, block, index, all_blocks) do
    list_item = "<li>#{Enum.at(block["bulleted_list_item"]["rich_text"], 0)["plain_text"]}</li>"

    cond do
      index > 0 and Enum.at(all_blocks, index - 1)["type"] != "bulleted_list_item" ->
        "<ul>#{list_item}"

      index < length(all_blocks) - 1 and
          Enum.at(all_blocks, index + 1)["type"] != "bulleted_list_item" ->
        "#{list_item}</ul>"

      true ->
        list_item
    end
  end

  def parse_block!(:numbered_list_item, block, index, all_blocks) do
    list_item = "<li>#{parse_rich_text(block["numbered_list_item"]["rich_text"])}</li>"

    cond do
      index > 0 and Enum.at(all_blocks, index - 1)["type"] != "numbered_list_item" ->
        "<ol>#{list_item}"

      index < length(all_blocks) - 1 and
          Enum.at(all_blocks, index + 1)["type"] != "numbered_list_item" ->
        "#{list_item}</ol>"

      true ->
        list_item
    end
  end

  def parse_rich_text(text) do
    cond do
      is_list(text) -> Enum.map(text, &parse_rich_text_node/1) |> Enum.join("")
      is_map(text) -> parse_rich_text_node(text)
      true -> ""
    end
  end

  def parse_rich_text_node(rich_text_node) do
    prefix =
      cond do
        rich_text_node["annotations"]["code"] == true -> "<code class=\"inline\">"
        rich_text_node["href"] != nil -> "<a href=\"#{rich_text_node["href"]}\">"
        true -> ""
      end

    suffix =
      cond do
        rich_text_node["annotations"]["code"] == true -> "</code>"
        rich_text_node["href"] != nil -> "</a>"
        true -> ""
      end

    prefix <> rich_text_node["plain_text"] <> suffix
  end
end
