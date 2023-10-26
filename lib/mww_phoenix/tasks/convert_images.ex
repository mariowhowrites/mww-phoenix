defmodule MwwPhoenix.Tasks.ConvertImages do
  use Task

  alias MwwPhoenix.ResponsiveImageGenerator

  def start_link(_arg) do
    Task.start_link(__MODULE__, :run, [])
  end

  def run() do
    ResponsiveImageGenerator.generate_responsive_images()
  end
end
