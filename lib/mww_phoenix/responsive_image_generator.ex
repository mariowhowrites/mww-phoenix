# defmodule MwwPhoenix.ResponsiveImageGenerator do
#   alias MwwPhoenix.Image

#   @moduledoc """
#   This module is used to generate responsive images for the website.
#   """

#   @doc """
#   This function is used to generate responsive images for the website.

#   Firstly, we want to fetch every image in the priv/content directory.
#   Then, we want to generate a responsive image for each image.
#   Finally, we want to save the responsive image in the priv/static directory.
#   """
#   def generate_responsive_images(%MwwPhoenix.Image{} = image, dimensions) do
#     # # fetch all images in the priv/content directory
#     # old_paths = get_content_images()

#     dimensions
#     |> Enum.each(fn width ->
#       image_name = Image.get_image_name_from_path(image.storage_path)
#       new_path = Application.app_dir(:mww_phoenix, "priv/static/images/#{image.type}/responsive/#{width}/#{image_name}")

#       run_imagemagick(old_path, new_path, width)
#     end)
#   end


#   defp run_imagemagick(old_file_path, new_file_path, width) do
#     # from https://www.smashingmagazine.com/2015/06/efficient-image-resizing-with-imagemagick/
#     System.cmd("convert", [
#       old_file_path,
#       "-filter",
#       "Triangle",
#       "-define",
#       "filter:support=2",
#       "-thumbnail",
#       width,
#       "-unsharp",
#       "0.25x0.25+8+0.065",
#       "-dither",
#       "None",
#       "-posterize",
#       "136",
#       "-quality",
#       "82",
#       "-define",
#       "jpeg:fancy-upsampling=off",
#       "-define",
#       "png:compression-level=9",
#       "-define",
#       "png:compression-strategy=1",
#       "-define",
#       "png:exclude-chunk=all",
#       "-interlace",
#       "none",
#       "-colorspace",
#       "sRGB",
#       "-strip",
#       new_file_path
#     ])
#   end

#   def dimensions(), do: @dimensions
# end
