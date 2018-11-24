defmodule SPV do
 @moduledoc """
    This module implements a SPV - i.e wallet.
    """
    use GenServer, restart: :temporary

     # External API
  def start_link([input_name, public_key, private_key, associated_full_node]) do
    GenServer.start_link(
      __MODULE__,
      %{
        :name => input_name,
        :public_key => public_key,
        :private_key => private_key,
        :associated_full_node => associated_full_node,
      },
      name: input_name
    )
  end

  # Genserver Implementation
  def init(initial_map) do
    {:ok, initial_map}
  end


# 1. Get all required blocks from associated full node
# 2. Check if inputs are valid
# 3. Check Merkle root as well
# 4. Make transaction (Make sure signature is done)
# 5. Send to associated nodes {:add_transaction}

end
