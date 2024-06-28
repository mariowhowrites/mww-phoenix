defmodule MwwPhoenix.Notion.RendererTest do
  alias MwwPhoenix.ContentBuilder.Notion.{Article, Interpreter, Renderer}
  use ExUnit.Case

  setup_all do
    article = %Article{
      category: "Technical",
      description: "Some cool description",
      title: "Test Article",
      slug: "test-article",
      date: "321312",
      published: true,
      published_dev: true,
      image: "images/example.jpg",
      tags: []
    }

    {:ok,
     %{
       article: article,
       all_blocks:
         Interpreter.interpret_content(
           article,
           Jason.decode!(File.read!("priv/stubs/notion.json"))
         )
     }}
  end

  test "example", state do
    state.all_blocks
    |> Renderer.render_blocks(state.article)
    |> IO.inspect()
  end
end
