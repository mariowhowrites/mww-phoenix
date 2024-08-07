defmodule MwwPhoenix.Notion.InterpreterTest do
  alias MwwPhoenix.ContentBuilder.Notion.{Article, Interpreter}
  use ExUnit.Case

  setup_all do
    {:ok,
     %{
       all_blocks: Jason.decode!(File.read!("priv/stubs/notion.json"))
     }}
  end

  # test "example", state do
  #   article = %Article{
  #     category: "Technical",
  #     description: "Some cool description",
  #     title: "Test Article",
  #     slug: "test-article",
  #     date: "321312",
  #     published: true,
  #     published_dev: true,
  #     image: "images/example.jpg",
  #     tags: []
  #   }

  #   interpreted_blocks = Interpreter.interpret_content(article, state.all_blocks)
  # end
end
