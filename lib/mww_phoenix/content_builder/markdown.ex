defmodule MwwPhoenix.ContentBuilder.Markdown do
  def build() do
    File.ls!(Application.app_dir(:mww_phoenix, "priv/content"))
    |> Enum.map(&parse_post!/1)
  end

  # we want a function that parses a file line by line --
  # once we find the first "---", start parsing line-by-line
  # each line we find should be split on ":" to create k/v pairs
  # once we find the second "---", everything after that should be collected and passed to a markdown parser
  defp parse_post!(slug) do
    post_path = Application.app_dir(:mww_phoenix, "priv/content/#{slug}/index.md")

    data = File.read!(post_path)

    case String.split(data, ~r/\n-{3,}\n/, parts: 2) do
      [""] -> %{frontmatter: nil, content: nil}
      [frontmatter, content] -> post_from_markdown(frontmatter, content)
    end
  end


  defp post_from_markdown(frontmatter, content) do
    {:ok, frontmatter} = YamlElixir.read_from_string(frontmatter, atoms: true)
    {:ok, content, _warnings} = Earmark.as_html(content)

    article = Map.merge(frontmatter, %{
      "content" => content
    })

    for {key, value} <- article, into: %{}, do: {String.to_atom(key), value}
  end
end
