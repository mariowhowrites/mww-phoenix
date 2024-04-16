defmodule MwwPhoenix.ContentBuilder do
  @source Application.compile_env(:mww_phoenix, MwwPhoenix.ContentBuilder)[:source]

  def build() do
    case @source do
      :notion -> MwwPhoenix.ContentBuilder.Notion.build()
      :markdown -> MwwPhoenix.ContentBuilder.Markdown.build()
    end
  end
end
