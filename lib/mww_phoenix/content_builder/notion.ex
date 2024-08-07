defmodule MwwPhoenix.ContentBuilder.Notion do
  use MwwPhoenixWeb, :controller
  alias MwwPhoenix.ContentBuilder.Notion.{Client, Interpreter, Renderer}

  def build() do
    database_id = Application.fetch_env!(:mww_phoenix, :notion)[:database_id]

    {:ok, res} = Client.get_published_articles_in_database(database_id)

    res.body["results"]
    |> Enum.map(&Interpreter.interpret_article/1)
    |> Enum.map(&Renderer.render_article/1)
  end

  defmodule Block do
    @derive Jason.Encoder
    defstruct content: [], type: nil, metadata: %{}, children: []

    @type t :: %__MODULE__{
            content: list(String.t() | t()),
            type: block_type(),
            metadata: map(),
            children: list(t())
          }

    @type block_type ::
            :paragraph
            | :heading_1
            | :heading_2
            | :heading_3
            | :code
            | :to_do
            | :bulleted_list_item
            | :table
            | :toggle
            | :quote
            | :divider
            | :child_page
            | :unsupported
            | :callout
            | :image
            | :bookmark
            | :video
            | :embed
            | :table_of_contents
  end

  defmodule Article do
    defstruct category: "",
              description: "",
              title: "",
              slug: "",
              date: nil,
              published: false,
              published_dev: false,
              image: "",
              tags: [],
              content: [],
              notion_id: ""

    @type t :: %__MODULE__{
            category: String.t(),
            content: list(Block.t()),
            image: String.t(),
            slug: String.t(),
            date: String.t(),
            published: boolean(),
            published_dev: boolean(),
            tags: list(String.t())
          }
  end
end
