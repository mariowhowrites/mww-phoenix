defmodule MwwPhoenix.ContentBuilder.Notion.Block do
  defstruct content: [], type: nil, metadata: %{}, children: []

  @type t :: %__MODULE__{
          content: list(String.t() | Block.t()),
          type: Atom.t(),
          metadata: Map.t(),
          children: list(Block.t())
        }

  @block_types [
    :paragraph,
    :heading_1,
    :heading_2,
    :heading_3,
    :code,
    :to_do,
    :bulleted_list_item,
    :table,
    :toggle,
    :quote,
    :divider,
    :child_page,
    :unsupported,
    :callout,
    :image,
    :bookmark,
    :video,
    :embed,
    :table_of_contents
  ]
end
