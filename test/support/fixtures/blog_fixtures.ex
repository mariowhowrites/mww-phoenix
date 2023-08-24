defmodule MwwPhoenix.BlogFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `MwwPhoenix.Blog` context.
  """

  @doc """
  Generate a article.
  """
  def article_fixture(attrs \\ %{}) do
    {:ok, article} =
      attrs
      |> Enum.into(%{
        content: "some content",
        title: "some title"
      })
      |> MwwPhoenix.Blog.create_article()

    article
  end
end
