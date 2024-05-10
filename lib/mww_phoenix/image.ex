defmodule MwwPhoenix.Image do
  require Logger

  defstruct type: nil, storage_path: nil

  def get_local_body_image_url(url, slug) do
    internal_storage_path = build_save_path_from_url({:body_image, url}, slug)

    case File.exists?(internal_storage_path) do
      true ->
        {:ok,
         %__MODULE__{
           type: :body_image,
           storage_path: internal_storage_path
         }}

      false ->
        case download_body_image(url, internal_storage_path) do
          {:ok, image} ->
            {:ok, image}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  def get_local_cover_image_url(url, slug) do
    internal_storage_path = build_save_path_from_url({:cover_image, url}, slug)

    case File.exists?(internal_storage_path) do
      true ->
        {:ok, %__MODULE__{type: :cover_image, storage_path: internal_storage_path}}

      false ->
        case download_cover_image(url, internal_storage_path) do
          {:ok, save_path} ->
            {:ok, save_path}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  def download_body_image(url, storage_path, get_fn \\ &Req.get/1) do
    case download_from_url(url, storage_path, get_fn) do
      {:ok, save_path} ->
        {:ok, %__MODULE__{type: :body_image, storage_path: save_path}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def download_cover_image(url, storage_path, get_fn \\ &Req.get/1) do
    case download_from_url(url, storage_path, get_fn) do
      {:ok, save_path} ->
        {:ok, %__MODULE__{type: :cover_image, storage_path: save_path}}

      {:error, _} ->
        {:error, "Failed to download the image"}
    end
  end

  defp download_from_url(url, save_path, get_fn) do
    case get_fn.(url) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        case File.write(save_path, body) do
          :ok ->
            Logger.info("Image downloaded and saved successfully.")
            {:ok, save_path}

          error ->
            Logger.error("Failed to save the image: #{inspect(error)}")
            {:error, "Failed to save the image"}
        end

      {:ok, %Req.Response{status: status_code}} ->
        Logger.error("Failed to download the image. Status code: #{status_code}")
        {:error, "Failed to download the image"}

      {:error, error} ->
        Logger.error("Failed to download the image: #{inspect(error)}")
        {:error, "Failed to download the image"}
    end
  end

  def build_save_path_from_url({:body_image, url}, slug) do
    directory_path = build_save_directory_path_from_url({:body_image, slug})

    if !File.exists?(directory_path) do
      File.mkdir!(directory_path)
    end

    directory_path <> "/" <> get_image_name_from_url(url)
  end

  def build_save_path_from_url({:cover_image, url}, slug) do
    directory_path = build_save_directory_path_from_url({:cover_image, slug})

    if !File.exists?(directory_path) do
      File.mkdir!(directory_path)
    end

    directory_path <> "/" <> get_image_name_from_url(url)
  end

  def build_save_directory_path_from_url({:body_image, slug}) do
    to_string(:code.priv_dir(:mww_phoenix)) <>
      "/static/images/body_images/#{slug}"
  end

  def build_save_directory_path_from_url({:cover_image, slug}) do
    to_string(:code.priv_dir(:mww_phoenix)) <>
      "/static/images/cover_images/#{slug}"
  end

  def get_image_name_from_url(url) do
    [name, _rest] = Path.basename(url) |> String.split("?")

    name
  end

  def get_local_path_from_storage_path(storage_path) do
    [_, local_path] = String.split(storage_path, "priv/static")

    local_path
  end
end
