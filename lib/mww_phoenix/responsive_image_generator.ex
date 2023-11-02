defmodule MwwPhoenix.ResponsiveImageGenerator do
  @dimensions [
    mobile: "512",
    desktop: "1400"
  ]

  @moduledoc """
  This module is used to generate responsive images for the website.
  """

  @doc """
  This function is used to generate responsive images for the website.

  Firstly, we want to fetch every image in the priv/content directory.
  Then, we want to generate a responsive image for each image.
  Finally, we want to save the responsive image in the priv/static directory.
  """
  def generate_responsive_images() do
    # fetch all images in the priv/content directory
    old_paths = Path.wildcard("priv/content/**/*.{jpg,jpeg,png,avif,webp}")

    # generate a responsive image for each image
    Enum.each(old_paths, fn old_path ->
      Enum.each(@dimensions, fn {device, width} ->
        image_name = Path.basename(old_path)
        new_path = Application.app_dir(:mww_phoenix, "priv/static/images/responsive/#{device}/#{image_name}")

        run_imagemagick(old_path, new_path, width)
      end)
    end)
  end

  defp run_imagemagick(old_file_path, new_file_path, width) do
    # from https://www.smashingmagazine.com/2015/06/efficient-image-resizing-with-imagemagick/
    System.cmd("convert", [
      old_file_path,
      "-filter",
      "Triangle",
      "-define",
      "filter:support=2",
      "-thumbnail",
      width,
      "-unsharp",
      "0.25x0.25+8+0.065",
      "-dither",
      "None",
      "-posterize",
      "136",
      "-quality",
      "82",
      "-define",
      "jpeg:fancy-upsampling=off",
      "-define",
      "png:compression-level=9",
      "-define",
      "png:compression-strategy=1",
      "-define",
      "png:exclude-chunk=all",
      "-interlace",
      "none",
      "-colorspace",
      "sRGB",
      "-strip",
      new_file_path
    ])
  end

  def dimensions(), do: @dimensions
end
