defmodule MwwPhoenix.ContentBuilder do
  @source Application.compile_env(:mww_phoenix, [MwwPhoenix.ContentBuilder, :source], :notion)

  def build() do
    case @source do
      :notion -> MwwPhoenix.ContentBuilder.Notion.build()
      :markdown -> MwwPhoenix.ContentBuilder.Markdown.build()
      _ -> []
    end
  end
end
