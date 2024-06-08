defmodule MwwPhoenixWeb.AboutLive.AboutLive do
  use MwwPhoenixWeb, :live_view

  def handle_params(unsigned_params, uri, socket) do
    {:noreply, socket |> assign(:page_title, "About")}
  end
end
