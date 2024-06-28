defmodule MwwPhoenix.ContentBuilder.Notion.Renderer do
  alias MwwPhoenix.ContentBuilder.Notion.Block

  @groupable_types [:bulleted_list_item, :numbered_list_item]

  def render_article({article, all_blocks}) do
    rendered_content = render_blocks(all_blocks, article)

    Map.put(article, :content, rendered_content)
  end

  def render_blocks(all_blocks, article) do
    all_blocks
    |> group_blocks()
    |> Enum.map(fn block_group ->
      render_group(block_group, article: article, all_blocks: all_blocks)
    end)
  end

  def group_blocks(all_blocks) do
    Enum.chunk_while(
      all_blocks,
      [],
      fn
        %Block{type: type} = block, acc when type in @groupable_types ->
          # if the type of the block matches the type of the first element of acc, add element to acc and return
          if Enum.at(acc, 0).type == type do
            {:cont, acc ++ [block]}
          else
            {:cont, [block]}
          end

        block, [] ->
          {:cont, [block]}

        block, acc ->
          {:cont, acc, [block]}
      end,
      fn acc -> {:cont, acc} end
    )
  end

  def render_group(blocks, opts) when length(blocks) == 1 do
    render_block(Enum.at(blocks, 0), opts)
  end

  def render_group(blocks, opts) when length(blocks) > 1 do
    [prefix, suffix] =
      cond do
        Enum.at(blocks, 0).type == :bulleted_list_item -> ["<ul>", "</ul>"]
        Enum.at(blocks, 0).type == :numbered_list_item -> ["<ol>", "</ol>"]
      end

    ([prefix] ++ Enum.map(blocks, &render_block(&1, opts)) ++ [suffix]) |> Enum.join("")
  end

  def render_block(block, opts \\ [])

  def render_block(%Block{} = block, opts) when block.type == :paragraph do
    (["<p>"] ++ render_content(block.content, opts) ++ ["</p>"])
    |> Enum.join("")
  end

  def render_block(%Block{} = block, opts) when block.type == :text do
    block.content |> Enum.join("")
  end

  def render_block(%Block{} = block, opts) when block.type == :heading_1 do
    (["<h1>"] ++ block.content ++ ["</h1>"])
    |> Enum.join("")
  end

  def render_block(%Block{} = block, opts) when block.type == :heading_2 do
    (["<h2>"] ++ block.content ++ ["</h2>"])
    |> Enum.join("")
  end

  def render_block(%Block{} = block, opts) when block.type == :heading_3 do
    (["<h3>"] ++ block.content ++ ["</h3>"])
    |> Enum.join("")
  end

  # render_block for image type
  def render_block(%Block{} = block, opts) when block.type == :image do
    [image_path] = block.content

    "<img src=\"#{image_path}\" alt=\"#{block.metadata.caption}\">"
  end

  def render_block(%Block{} = block, opts) when block.type == :inline_code do
    (["<code class=\"inline\">"] ++ block.content ++ ["</pre>"])
    |> Enum.join("")
  end

  def render_block(%Block{} = block, opts) when block.type == :code do
    [code] = block.content

    (["<pre><code class=\"hljs language-#{block.metadata.language}\">"] ++
       [HtmlEntities.encode(code)] ++ ["</code></pre>"])
    |> Enum.join("")
  end

  def render_block(%Block{} = block, opts) when block.type == :image do
    [image_path] = block.content

    "<img src=\"#{image_path}\" alt=\"#{block.caption}\">"
  end

  def render_block(%Block{} = block, opts) when block.type == :child_page do
    ""
  end

  def render_block(%Block{} = block, opts) when block.type == :divider do
    "<hr>"
  end

  def render_block(%Block{} = block, opts) when block.type == :video do
    "<iframe
      width=\"560\"
      height=\"315\"
      src=\"https://www.youtube-nocookie.com/embed/#{block.metadata.video_id}\"
      title=\"YouTube video player\"
      frameborder=\"0\"
      allow=\"accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share\"
      referrerpolicy=\"strict-origin-when-cross-origin\"
      allowfullscreen></iframe>"
  end

  # render_block for to_do type, should handle recursive case in case of nested todo lists
  def render_block(%Block{} = block, opts) when block.type == :to_do do
    content = render_content(block.content, opts)

    if block.metadata.checked do
      "<input type=\"checkbox\" checked disabled> #{content}"
    else
      "<input type=\"checkbox\" disabled> #{content}"
    end
  end

  # render_block for bulleted_list_item
  def render_block(%Block{} = block, opts) when block.type in @groupable_types do
    # list_item = ["<li>"] ++ render_content(block.content, opts) ++ ["</li>"]

    # index = opts[:index]
    # all_blocks = opts[:all_blocks]

    # list_item =
    #   cond do
    #     index > 0 and Enum.at(all_blocks, index - 1).type != :bulleted_list_item ->
    #       ["<ul>"] ++ list_item

    #     index < length(all_blocks) - 1 and
    #         Enum.at(all_blocks, index + 1).type != :bulleted_list_item ->
    #       list_item ++ ["</ul>"]

    #     true ->
    #       list_item
    #   end

    # (list_item ++ render_content(block.children, opts)) |> Enum.join("")
    (["<li>"] ++ render_content(block.content, opts) ++ ["</li>"]) |> Enum.join("")
  end

  # render_block for table. atm this isn't a high priority so let's just return nothing
  def render_block(%Block{} = block, opts) when block.type == :table do
    ""
  end

  # render_block for toggles. this needs JS to work effectively, so for now let's also return nothing
  def render_block(%Block{} = block, opts) when block.type == :toggle do
    ""
  end

  # render_block for quote
  def render_block(%Block{} = block, opts) when block.type == :quote do
    "<blockquote>#{render_content(block.content, opts)}</blockquote>"
  end

  # render_block for unsupported
  def render_block(%Block{} = block, opts) when block.type == :unsupported do
    ""
  end

  # render_block for callout
  def render_block(%Block{} = block, opts) when block.type == :callout do
    "<aside class=\"callout\">
      <div>#{block.metadata.emoji}</div>
      <div>#{render_content(block.content, opts)}</div>
    </aside>"
  end

  # render_block for bookmark. let's just use a link for now and revisit this later
  def render_block(%Block{} = block, opts) when block.type == :bookmark do
    "<a href=\"#{block.metadata.url}\">#{block.content}</a>"
  end

  def render_block(%Block{} = block, opts) when block.type == :embed do
    ""
  end

  def render_block(%Block{} = block, opts) when block.type == :table_of_contents do
    ""
  end

  def render_block(%Block{} = block, opts) when block.type == :link do
    "<a href=\"#{block.metadata.url}\">#{hd(block.content)}</a>"
  end

  defp render_content(content, opts) do
    Enum.map(content, &render_block(&1, opts))
  end
end
