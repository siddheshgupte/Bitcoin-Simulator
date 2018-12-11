defmodule Proj4Web.RoomChannel do
    use Phoenix.Channel
  
    def join("room:lobby", _message, socket) do
      {:ok, socket}
    end
    def join("room:" <> _private_room_id, _params, _socket) do
      {:error, %{reason: "unauthorized"}}
    end

    def handle_in("new_msg", %{"body" => body}, socket) do
        broadcast!(socket, "new_msg", %{body: body})
        {:noreply, socket}
    end 

    def handle_in("new_time", msg, socket) do
        push socket, "new_time", msg
        {:noreply, socket}
    end

  end