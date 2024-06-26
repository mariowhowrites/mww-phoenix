defmodule MwwPhoenix.ContentBuilder.Notion.Interpreter do
  alias MwwPhoenix.Image
  alias MwwPhoenix.ContentBuilder.Notion.{Article, Block, Client}

  def interpret_article!(%{"id" => id}) do
    {:ok, raw_metadata} = Client.get_page_metadata(id)
    {:ok, page_children} = Client.get_children(id)

    raw_metadata
    |> interpret_metadata()
    |> interpret_content(page_children.body["results"])
  end

  def interpret_metadata(%{:body => %{"properties" => properties}} = metadata) do
    slug = get_text_property(properties, "Slug", "rich_text")
    external_image_path = Enum.at(metadata.body["properties"]["Image"]["files"], 0)["file"]["url"]
    {:ok, image} = Image.find_or_create(:cover_image, external_image_path, slug)

    %Article{
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

  def interpret_content(%Article{} = article, all_blocks) do
    all_blocks
    |> Enum.with_index()
    |> Enum.map(fn {block, index} ->
      interpret_block(
        String.to_existing_atom(block["type"]),
        block,
        index: index,
        all_blocks: all_blocks,
        article: article
      )
    end)
  end

  def interpret_block(type, block, opts \\ [])

  def interpret_block(:paragraph, block, _opts) do
    %Block{
      type: :paragraph,
      content: [parse_rich_text(block["paragraph"]["rich_text"])]
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
    interpreted_block = %Block{
      type: :bulleted_list_item,
      content: parse_rich_text(block["bulleted_list_item"]["rich_text"])
    }

    if block["has_children"] do
      parse_block_children(block, interpreted_block, opts)
    else
      interpreted_block
    end
  end

  # we'll have to move most of this logic into the renderer
  def interpret_block(:numbered_list_item, block, opts) do
    interpreted_block = %Block{
      type: :numbered_list_item,
      content: parse_rich_text(block["numbered_list_item"]["rich_text"])
    }

    if block["has_children"] do
      parse_block_children(block, interpreted_block, opts)
    else
      interpreted_block
    end
  end

  def interpret_block(:to_do, block, opts) do
    interpreted_block = %Block{
      type: :to_do,
      content: parse_rich_text(block["to_do"]["rich_text"]),
      metadata: %{
        checked: block["to_do"]["checked"]
      }
    }

    if block["has_children"] do
      parse_block_children(block, interpreted_block, opts)
    else
      interpreted_block
    end
  end

  # will need to be handled recursively
  def interpret_block(:table, block, _opts) do
    %Block{
      type: :table,
      content: []
    }
  end

  # also need recursive
  def interpret_block(:toggle, block, opts) do
    interpreted_block = %Block{
      type: :toggle,
      content: []
    }

    if block["has_children"] do
      parse_block_children(block, interpreted_block, opts)
    else
      interpreted_block
    end
  end

  def interpret_block(:quote, block, _opts) do
    %Block{
      type: :quote,
      content: [parse_rich_text(block["quote"]["rich_text"])]
    }
  end

  def interpret_block(:unsupported, block, _opts) do
    %Block{
      type: :unsupported,
      content: []
    }
  end

  def interpret_block(:callout, block, _opts) do
    %Block{
      type: :callout,
      content: [parse_rich_text(block["callout"]["rich_text"])],
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

  # helpers fns

  defp get_text_property(properties, key, type) do
    properties[key][type]
    |> Enum.at(0)
    |> Map.get("text")
    |> Map.get("content")
  end

  def parse_rich_text(text) do
    cond do
      is_list(text) -> Enum.map(text, &parse_rich_text_node/1)
      is_map(text) -> parse_rich_text_node(text)
      true -> ""
    end
  end

  def parse_rich_text_node(rich_text_node) do
    type =
      cond do
        rich_text_node["annotations"]["code"] == true -> :inline_code
        rich_text_node["href"] != nil -> :link
        true -> :text
      end

    %Block{
      type: type,
      content: [rich_text_node["plain_text"]]
    }
  end

  defp parse_block_children(raw_block, interpreted_block, opts) do
    {:ok, res} = Client.get_children(raw_block["id"])
    block_children = res.body["results"]

    interpreted_children =
      Enum.map(
        block_children,
        &interpret_block(String.to_existing_atom(&1["type"]), &1, opts)
      )

    Map.put(interpreted_block, :children, interpreted_children)
  end

  defp debug_print(block) do
    Jason.encode!(block)
  end
end
