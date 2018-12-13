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

    # This function creates a transaction from the user inputs
    def handle_in("mining_amount", %{"amount" => amount, "receiver" => receiverIndex}, socket) do
      {receiverIndex, _} =Integer.parse(receiverIndex)
      {public_key, _} = :crypto.generate_key(:ecdh, :secp256k1,  receiverIndex-1)
      receiver = public_key |> Base.encode16()
      GenServer.cast(:wallet_0441920A72D0B2F76C2D5DB39E034060C38B12B07F99DFCDD6063888312818DF15FC78834C3FE49EBB32B1E7DB540D08A3E07FA8C1D05D3C43A848BE8C8BFCCCA1,
       {:make_transaction, receiver<>" "<>amount<>".0 1.0"})
        {:reply, :ok, socket}
    end

  end