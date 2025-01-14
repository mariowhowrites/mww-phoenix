defmodule MwwPhoenix.Image do
  alias MwwPhoenix.Blog
  alias Task.Supervisor
  require Logger

  @dimensions ["512", "1400"]

  defstruct type: nil, storage_path: nil, name: nil

  # Given the download URL and the slug of the article, this function:
  # 1. Builds the internal storage path for the image.
  # 2. Checks if the image already exists in the internal storage.
  # 3. If the image exists, it returns the image.
  # 4. If the image does not exist, it downloads the image and saves it in the internal storage.
  # 5. Returns {:ok, image} or {:error, reason}
  # def get_local_body_image_url(url, slug) do
  #   # determine the end location given the download URL and slug
  #   internal_storage_path = build_save_path_from_url({:body_image, url}, slug)

  def find_or_create(type, url, slug) do
    internal_storage_path = build_internal_storage_path(type, url, slug)

    case File.exists?(internal_storage_path) do
      true ->
        {:ok,
         %MwwPhoenix.Image{
           type: type,
           storage_path: internal_storage_path,
           name: get_image_name_from_path(internal_storage_path)
         }}

      false ->
        case download_from_url(url, internal_storage_path) do
          {:ok, save_path} ->
            image = %MwwPhoenix.Image{
              type: type,
              storage_path: save_path,
              name: get_image_name_from_path(save_path)
            }

            create_responsive_variants(image)

            {:ok, image}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  def create_responsive_variants(%MwwPhoenix.Image{} = image) do
    @dimensions
    |> Enum.each(fn width ->
      Task.Supervisor.start_child(MwwPhoenix.TaskSupervisor, fn ->
        MwwPhoenix.Image.generate_responsive_image(image, width)
      end)
    end)
  end

  defp download_from_url(url, save_path, get_fn \\ &Req.get/1) do
    Logger.info("Attempting to download image from #{url} to #{save_path}")

    case get_fn.(url) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        Logger.info("Download successful, file size: #{byte_size(body)} bytes")

        case File.write(save_path, body) do
          :ok ->
            Logger.info("Image saved successfully to #{save_path}")
            {:ok, save_path}

          error ->
            Logger.error("Failed to save image: #{inspect(error)}\nPath: #{save_path}\nPermissions: #{inspect(File.stat(Path.dirname(save_path)))}")
            {:error, "Failed to save the image"}
        end

      {:ok, %Req.Response{status: status_code}} ->
        Logger.error("Download failed with status #{status_code} for URL: #{url}")
        {:error, "Failed to download the image"}

      {:error, error} ->
        Logger.error("Download error: #{inspect(error)}\nURL: #{url}")
        {:error, "Failed to download the image"}
    end
  end

  def build_internal_storage_path(type, download_url, slug) do
    directory_path = build_save_directory_path(type, slug)

    if !File.exists?(directory_path) do
      File.mkdir!(directory_path)
    end

    directory_path <> "/" <> get_image_name_from_path(download_url)
  end

  def build_save_directory_path(:body_image, slug) do
    to_string(:code.priv_dir(:mww_phoenix)) <>
      "/static/images/body_images/#{slug}"
  end

  def build_save_directory_path(:cover_image, slug) do
    to_string(:code.priv_dir(:mww_phoenix)) <>
      "/static/images/cover_images/#{slug}"
  end

  def get_image_name_from_path(path) do
    Path.basename(path) |> String.split("?") |> Enum.at(0)
  end

  def get_local_path_from_storage_path(storage_path) do
    [_, local_path] = String.split(storage_path, "priv/static")

    local_path
  end

  def full_url(storage_path) do
    "https://#{Blog.site_hostname()}#{get_local_path_from_storage_path(storage_path)}"
  end

  def build_srcset(%MwwPhoenix.Image{} = image) do
    @dimensions
    |> Enum.map(fn width ->
      "/images/#{image.type}s/responsive/#{width}/#{image.name} #{width}w"
    end)
    |> Enum.join(", ")
  end

  @doc """
  This function is used to generate responsive images for the website.

  Firstly, we want to fetch every image in the priv/content directory.
  Then, we want to generate a responsive image for each image.
  Finally, we want to save the responsive image in the priv/static directory.
  """
  def generate_responsive_image(%MwwPhoenix.Image{} = image, width) do
    new_directory =
      Application.app_dir(
        :mww_phoenix,
        "priv/static/images/#{image.type}s/responsive/#{width}"
      )

    new_path =
      new_directory <> "/" <> image.name

    # only run imagemagick if we dont find anything at new path
    if !File.exists?(new_path) do
      ensure_directory_exists(new_directory)

      run_imagemagick(image.storage_path, new_path, width)
    end
  end

  def ensure_directory_exists(new_directory) do
    if !File.exists?(new_directory) do
      File.mkdir_p(new_directory)
    end
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
end
