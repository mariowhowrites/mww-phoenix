defmodule MwwPhoenix.Notion.RendererTest do
  alias Swoosh.Email.Render
  alias MwwPhoenix.ContentBuilder.Notion.{Article, Block, Interpreter, Renderer}
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
       article: article
       #  all_blocks:
       #    Interpreter.interpret_content(
       #      article,
       #      Jason.decode!(File.read!("priv/stubs/notion.json"))
       #    )
     }}
  end

  # test "example", state do
  #   state.all_blocks
  #   |> Renderer.render_blocks(state.article)
  # end

  test ":text returns the string without formatting" do
    block = %Block{
      type: :text,
      content: ["This is a test"]
    }

    assert Renderer.render_block(block) == "This is a test"
  end

  test ":bulleted_list_item returns a li element", _state do
    block = %Block{
      type: :bulleted_list_item,
      content: [text("Some content")]
    }

    assert Renderer.render_block(block) == "<li>Some content</li>"
  end

  test ":bulleted_list_item can render children", state do
    blocks =
      [
        bulleted_list_item("This is the parent bulleted list, first item", [
          bulleted_list_item("Child nested list item, first item"),
          bulleted_list_item("Child nested list item, second item")
        ]),
        bulleted_list_item("Parent list, second item")
      ]

    assert Renderer.render_blocks(blocks)  ==
             "<ul><li>This is the parent bulleted list, first item</li><ul><li>Child nested list item, first item</li><li>Child nested list item, second item</li></ul><li>Parent list, second item</li></ul>"
  end

  test ":table can render a table", state do
    blocks =
      table(
        [
          table_row([
            text("Name"),
            text("Occupation")
          ]),
          table_row([
            text("Sauron"),
            text("Lord of the Rings")
          ])
        ],
        has_column_header: true
      )

    assert Renderer.render_blocks(blocks) ==
             "<table><thead><tr><th>Name</th><th>Occupation</th></tr></thead><tbody><tr><td>Sauron</td><td>Lord of the Rings</td></tr></tbody></table>"
  end

  defp bulleted_list_item(content, children \\ []) do
    %Block{
      type: :bulleted_list_item,
      content: [text(content)],
      children: children
    }
  end

  defp text(content, children \\ []) do
    %Block{
      type: :text,
      content: [content],
      children: children
    }
  end

  defp table(children, opts \\ []) do
    %Block{
      type: :table,
      content: [],
      children: children,
      metadata: %{
        has_column_header: opts[:has_column_header] || false
      }
    }
  end

  def table_row(children) do
    %Block{
      type: :table_row,
      children: children
    }
  end
end
