defmodule MwwPhoenix.ContentBuilder.Notion.Article do
  import MwwPhoenix.ContentBuilder.Notion.Block

  defstruct category: "",
            description: "",
            title: "",
            slug: "",
            date: nil,
            published: false,
            published_dev: false,
            image: "",
            tags: [],
            content: []

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
