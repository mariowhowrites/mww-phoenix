defmodule MwwPhoenix.ContentBuilder.Notion.Renderer do
  alias MwwPhoenix.ContentBuilder.Notion.Block

  def render_block(%Block{} = block, opts \\ []) when block.type == :paragraph do
    (["<p>"] ++ Enum.map(render_block(block.content, opts)) ++ ["</p>"])
    |> Enum.join("")
  end

  def render_block(%Block{} = block, opts) when block.type == :inline_code do
    (["<code class=\"inline\">"] ++ block.content ++ ["</pre>"])
    |> Enum.join("")
  end

  def render_block(%Block{} = block, opts) when block.type == :code do
    [code] = block.content

    (["<pre><code class=\"hljs language-#{block.language}\">"] ++
       HtmlEntities.encode(code) ++ ["</code></pre>"])
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
end
