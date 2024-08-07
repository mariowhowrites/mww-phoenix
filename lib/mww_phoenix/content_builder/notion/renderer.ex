defmodule MwwPhoenix.ContentBuilder.Notion.Renderer do
  alias MwwPhoenix.ContentBuilder.Notion.{Article, Block}

  @groupable_types [:bulleted_list_item, :numbered_list_item, :to_do]

  @spec render_article({Article.t(), [Block.t()]}) :: Article.t()
  def render_article({article, all_blocks}) do
    Map.put(article, :content, render_blocks(all_blocks))
  end

  @spec render_blocks(Block.t() | [Block.t()]) :: String.t()
  def render_blocks(block_or_blocks)

  def render_blocks(all_blocks) do
    List.wrap(all_blocks)
    |> group_blocks()
    |> Enum.map(fn block_group ->
      render_group(block_group)
    end)
    |> Enum.join()
  end

  @spec group_blocks([Block.t()]) :: [[Block.t()]]
  def group_blocks(all_blocks) do
    Enum.chunk_while(
      all_blocks,
      [],
      &chunk_block/2,
      fn
        [] -> {:cont, []}
        chunk -> {:cont, chunk, []}
      end
    )
  end

  defp chunk_block(%Block{type: type} = block, acc) when type in @groupable_types do
    if length(acc) == 0 do
      {:cont, [block]}
    else
      if Enum.at(acc, 0).type == type do
        {:cont, acc ++ [block]}
      else
        {:cont, acc, [block]}
      end
    end
  end

  defp chunk_block(block, [] = _acc) do
    {:cont, [block]}
  end

  defp chunk_block(block, acc) do
    {:cont, acc, [block]}
  end

  @spec render_group([Block.t()]) :: String.t()
  def render_group(blocks)

  def render_group(blocks) when length(blocks) == 0 do
    ""
  end

  def render_group(blocks) do
    [prefix, suffix] =
      case Enum.at(blocks, 0).type do
        :bulleted_list_item -> ["<ul>", "</ul>"]
        :numbered_list_item -> ["<ol>", "</ol>"]
        :to_do -> ["<div class=\"todo-wrapper\">", "</div>"]
        _ -> ["", ""]
      end

    ([prefix] ++ Enum.map(blocks, &render_block/1) ++ [suffix]) |> Enum.join()
  end

  @spec render_block(Block.t()) :: String.t()
  def render_block(block)

  def render_block(%Block{type: :paragraph, content: content}) do
    (["<p>"] ++ Enum.map(content, &render_block/1) ++ ["</p>"])
    |> Enum.join()
  end

  def render_block(%Block{type: :text, content: content}) do
    content |> Enum.join()
  end

  def render_block(%Block{type: :heading_1, content: content}) do
    (["<h1>"] ++ content ++ ["</h1>"])
    |> Enum.join()
  end

  def render_block(%Block{type: :heading_2, content: content}) do
    (["<h2>"] ++ content ++ ["</h2>"])
    |> Enum.join()
  end

  def render_block(%Block{type: :heading_3, content: content}) do
    (["<h3>"] ++ content ++ ["</h3>"])
    |> Enum.join()
  end

  def render_block(%Block{type: :image, content: [image_path], metadata: %{caption: caption}}) do
    "<img src=\"#{image_path}\" alt=\"#{caption}\">"
  end

  def render_block(%Block{type: :inline_code, content: content}) do
    (["<code class=\"inline\">"] ++ content ++ ["</code>"])
    |> Enum.join()
  end

  def render_block(%Block{type: :code, content: [code], metadata: %{language: language}}) do
    (["<pre><code class=\"hljs language-#{language}\">"] ++
       [HtmlEntities.encode(code)] ++ ["</code></pre>"])
    |> Enum.join()
  end

  def render_block(%Block{type: :child_page}) do
    ""
  end

  def render_block(%Block{type: :divider}) do
    "<hr>"
  end

  def render_block(%Block{type: :video, metadata: %{video_id: video_id}}) do
    "<iframe
      width=\"560\"
      height=\"315\"
      src=\"https://www.youtube-nocookie.com/embed/#{video_id}\"
      title=\"YouTube video player\"
      frameborder=\"0\"
      allow=\"accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share\"
      referrerpolicy=\"strict-origin-when-cross-origin\"
      allowfullscreen></iframe>"
  end

  def render_block(%Block{type: :to_do, content: content, children: children, metadata: %{checked: checked}}) do
    rendered_content = Enum.map(content, &render_block/1) |> Enum.join()

    checkbox =
      if checked do
        "<input type=\"checkbox\" checked disabled>"
      else
        "<input type=\"checkbox\" disabled>"
      end

    to_do_item = "<div class=\"to-do\">
      <div class=\"checkbox\">#{checkbox}</div>
      <div class=\"content\">#{rendered_content}</div>
    </div>"

    child_content = render_blocks(children)

    (List.wrap(to_do_item) ++ List.wrap(child_content)) |> Enum.join()
  end

  def render_block(%Block{type: type, content: content, children: children})
      when type in @groupable_types do
    prefix = ["<li>"]
    suffix = ["</li>"]
    block_content = Enum.map(content, &render_block/1)
    child_content = render_blocks(children)

    (prefix ++ block_content ++ suffix ++ List.wrap(child_content)) |> Enum.join()
  end

  def render_block(%Block{
        type: :table,
        children: table_rows,
        metadata: %{has_column_header: has_column_header}
      }) do
    prefix = ["<table>"]
    suffix = ["</table>"]

    table_content =
      case has_column_header do
        true ->
          [header_row | body_rows] = table_rows

          header = ["<thead>"] ++ (header_row |> render_blocks() |> List.wrap()) ++ ["</thead>"]

          body = ["<tbody>"] ++ (body_rows |> render_blocks() |> List.wrap()) ++ ["</tbody>"]

          header ++ body

        false ->
          ["<tbody>"] ++ (table_rows |> render_blocks() |> List.wrap()) ++ ["</tbody>"]
      end

    (prefix ++ table_content ++ suffix) |> Enum.join()
  end

  def render_block(%Block{type: :table_row, content: content}) do
    (["<tr>"] ++
       Enum.map(content, fn cell ->
         (["<td>"] ++ (cell |> render_block() |> List.wrap()) ++ ["</td>"]) |> Enum.join()
       end) ++
       ["</tr>"])
    |> Enum.join()
  end

  def render_block(%Block{type: :toggle}) do
    ""
  end

  def render_block(%Block{type: :quote, content: content}) do
    "<blockquote>#{Enum.map(content, &render_block/1) |> Enum.join()}</blockquote>"
  end

  def render_block(%Block{type: :unsupported}) do
    ""
  end

  def render_block(%Block{type: :callout, content: content, metadata: %{emoji: emoji}}) do
    "<aside class=\"callout\">
      <div>#{emoji}</div>
      <div>#{Enum.map(content, &render_block/1) |> Enum.join()}</div>
    </aside>"
  end

  def render_block(%Block{type: :bookmark, content: _content, metadata: %{url: _url}}) do
    # "<a href=\"#{url}\">#{content}</a>"
    ""
  end

  def render_block(%Block{type: :embed}) do
    ""
  end

  def render_block(%Block{type: :table_of_contents}) do
    ""
  end

  def render_block(%Block{type: :link, content: [content], metadata: %{url: url}}) do
    "<a href=\"#{url}\">#{content}</a>"
  end
end
