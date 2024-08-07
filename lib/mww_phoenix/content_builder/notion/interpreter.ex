defmodule MwwPhoenix.ContentBuilder.Notion.Interpreter do
  alias MwwPhoenix.Image
  alias MwwPhoenix.ContentBuilder.Notion.{Article, Block, Client}

  @spec interpret_article(map()) :: {Article.t(), [Block.t()]}
  def interpret_article(%{"id" => id}) do
    {:ok, raw_metadata} = Client.get_page_metadata(id)
    {:ok, page_children} = Client.get_children(id)

    raw_metadata
    |> interpret_metadata()
    |> interpret_content(page_children.body["results"])
  end

  @spec interpret_metadata(%{:body => %{}, optional(any()) => any()}) :: Article.t()
  def interpret_metadata(%{:body => %{"properties" => properties, "id" => id}} = metadata) do
    slug = get_text_property(properties, "Slug", "rich_text")
    external_image_path = Enum.at(metadata.body["properties"]["Image"]["files"], 0)["file"]["url"]
    {:ok, image} = Image.find_or_create(:cover_image, external_image_path, slug)

    %Article{
      notion_id: id,
      category: Enum.at(properties["Category"]["multi_select"], 0)["name"],
      description: get_text_property(properties, "Description", "rich_text"),
      title: get_text_property(properties, "Title", "title"),
      slug: slug,
      date: metadata.body["properties"]["Published On"]["date"]["start"],
      published: metadata.body["properties"]["Published"]["checkbox"],
      published_dev: metadata.body["properties"]["Published_dev"]["checkbox"],
      image: image.storage_path,
      tags: []
    }
  end

  @spec interpret_content(Article.t(), [map()]) :: {Article.t(), [Block.t()]}
  def interpret_content(%Article{} = article, all_blocks) do
    {
      article,
      all_blocks
      |> Enum.with_index()
      |> Enum.map(fn {block, index} ->
        interpret_block(
          block,
          index: index,
          all_blocks: all_blocks,
          article: article
        )
      end)
    }
  end

  @spec interpret_block(map(), Keyword.t()) :: Block.t()
  def interpret_block(block, opts) do
    interpret_block(
      String.to_existing_atom(block["type"]),
      block,
      opts
    )
    |> interpret_block_children(block, opts)
  end

  @spec interpret_block(Block.block_type(), map(), Keyword.t()) :: Block.t()
  def interpret_block(type, block, opts)

  def interpret_block(:paragraph, block, opts) do
    %Block{
      type: :paragraph,
      content: parse_rich_text(block["paragraph"]["rich_text"], opts)
    }
  end

  def interpret_block(:heading_1, block, _opts) do
    %Block{
      type: :heading_1,
      content: [Enum.at(block["heading_1"]["rich_text"], 0)["plain_text"]]
    }
  end

  def interpret_block(:heading_2, block, _opts) do
    %Block{
      type: :heading_2,
      content: [Enum.at(block["heading_2"]["rich_text"], 0)["plain_text"]]
    }
  end

  def interpret_block(:heading_3, block, _opts) do
    %Block{
      type: :heading_3,
      content: [Enum.at(block["heading_3"]["rich_text"], 0)["plain_text"]]
    }
  end

  def interpret_block(:code, block, opts) do
    %Block{
      type: :code,
      content: [Enum.at(block["code"]["rich_text"], 0)["plain_text"]],
      metadata: %{
        language: block["code"]["language"]
      }
    }
  end

  def interpret_block(:image, block, opts) do
    external_url = block["image"]["file"]["url"]

    {:ok, image} = Image.find_or_create(:body_image, external_url, opts[:article].slug)

    %Block{
      type: :image,
      content: [Image.get_local_path_from_storage_path(image.storage_path)],
      metadata: %{
        caption: Enum.at(block["image"]["caption"], 0)["plain_text"]
      }
    }
  end

  def interpret_block(:child_page, _block, _opts) do
    %Block{
      type: :child_page,
      content: []
    }
  end

  def interpret_block(:divider, _block, _opts) do
    %Block{
      type: :divider,
      content: []
    }
  end

  def interpret_block(:bulleted_list_item, block, opts) do
    %Block{
      type: :bulleted_list_item,
      content: parse_rich_text(block["bulleted_list_item"]["rich_text"], opts)
    }
  end

  # we'll have to move most of this logic into the renderer
  def interpret_block(:numbered_list_item, block, opts) do
    %Block{
      type: :numbered_list_item,
      content: parse_rich_text(block["numbered_list_item"]["rich_text"], opts)
    }
  end

  def interpret_block(:to_do, block, opts) do
    %Block{
      type: :to_do,
      content: parse_rich_text(block["to_do"]["rich_text"], opts),
      metadata: %{
        checked: block["to_do"]["checked"]
      }
    }
  end

  # will need to be handled recursively
  def interpret_block(:table, block, _opts) do
    IO.inspect(block)

    %Block{
      type: :table,
      content: [],
      metadata: %{
        has_column_header: block["table"]["has_column_header"]
      }
    }
  end

  def interpret_block(:table_row, block, opts) do
    %Block{
      type: :table_row,
      content: Enum.map(block["table_row"]["cells"], fn cell ->
        [text_node] = cell

        interpret_block(text_node, opts)
      end)
    }
  end


  # also need recursive
  def interpret_block(:toggle, _block, _opts) do
    %Block{
      type: :toggle,
      content: []
    }
  end

  def interpret_block(:quote, block, opts) do
    %Block{
      type: :quote,
      content: parse_rich_text(block["quote"]["rich_text"], opts)
    }
  end

  def interpret_block(:unsupported, _block, _opts) do
    %Block{
      type: :unsupported,
      content: []
    }
  end

  def interpret_block(:callout, block, opts) do
    %Block{
      type: :callout,
      content: parse_rich_text(block["callout"]["rich_text"], opts),
      metadata: %{
        emoji: block["callout"]["icon"]["emoji"]
      }
    }
  end

  def interpret_block(:bookmark, block, _opts) do
    %Block{
      type: :bookmark,
      content: [],
      metadata: %{
        url: block["bookmark"]["url"]
      }
    }
  end

  # for now, let's assume all video links come from YouTube. we should expand this later
  def interpret_block(:video, block, _opts) do
    url = block["video"]["external"]["url"]

    [_rest, id] = String.split(url, "?v=")

    %Block{
      type: :video,
      content: [],
      metadata: %{
        video_id: id
      }
    }
  end

  def interpret_block(:embed, block, _opts) do
    %Block{
      type: :embed,
      content: []
    }
  end

  def interpret_block(:table_of_contents, block, _opts) do
    %Block{
      type: :table_of_contents,
      content: []
    }
  end

  def interpret_block(:text, block, _opts) do
    %Block{
      type: :text,
      content: [block["plain_text"]]
    }
  end

  def interpret_block(:link, block, _opts) do
    %Block{
      type: :link,
      content: [block["plain_text"]],
      metadata: %{
        url: block["href"]
      }
    }
  end

  def interpret_block(:inline_code, block, _opts) do
    %Block{
      type: :inline_code,
      content: [block["plain_text"]]
    }
  end

  # helpers fns

  defp get_text_property(properties, key, type) do
    properties[key][type]
    |> Enum.at(0)
    |> Map.get("text")
    |> Map.get("content")
  end

  def parse_rich_text(text, opts) do
    cond do
      is_list(text) -> Enum.map(text, &parse_rich_text_block(&1, opts))
      is_map(text) -> parse_rich_text_block(text, opts)
      true -> ""
    end
  end

  def parse_rich_text_block(block, opts) do
    type =
      cond do
        block["annotations"]["code"] == true -> :inline_code
        block["href"] != nil -> :link
        true -> :text
      end

    interpret_block(type, block, opts)
  end

  defp interpret_block_children(interpreted_block, %{"has_children" => true} = raw_block, opts) do
    {:ok, res} = Client.get_children(raw_block["id"])
    block_children = res.body["results"]

    Map.put(
      interpreted_block,
      :children,
      Enum.map(
        block_children,
        &interpret_block(
          &1,
          opts
        )
      )
    )
  end

  defp interpret_block_children(interpreted_block, _raw_block, _opts) do
    interpreted_block
  end
end
