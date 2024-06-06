defmodule MwwPhoenix.ImageTest do
  use ExUnit.Case

  alias MwwPhoenix.Image

  describe "images" do
    test "build_save_path_from_url/2 returns the correct path" do
      url = "https://example.com/image.jpg?something=wow"
      slug = "some-slug"

      assert String.contains?(Image.build_save_path_from_url({:cover_image, url}, slug), "priv/static/images/cover_images/some-slug/image.jpg")
      assert String.contains?(Image.build_save_path_from_url({:body_image, url}, slug), "priv/static/images/body_images/some-slug/image.jpg")
    end
  end
end
