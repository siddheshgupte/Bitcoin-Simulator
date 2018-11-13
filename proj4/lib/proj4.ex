defmodule Proj4 do
  use GenServer, restart: :temporary

  # External API
  def start_link([input_name, genesis_block]) do
    GenServer.start_link(
      __MODULE__,
      %{
        :public_key => input_name,
        :chain => genesis_block,
        :uncommitted_transactions => []
      },
      name: input_name
    )
  end

  # Genserver Implementation
  def init(initial_map) do
    {:ok, initial_map}
  end

  # Add a transaction to the front of the local uncommitted transaction list
  def handle_cast({:add_transaction, transaction}, current_map) when is_binary(transaction) do
    {_, current_map} =
      Map.get_and_update(current_map, :uncommitted_transactions, fn x ->
        {x, [transaction | x]}
      end)

    {:noreply, current_map}
  end

  def handle_cast({:mine, transaction}, current_map) when is_binary(transaction) do
    # Implement consensus
    # Make every node send {self.pid, chain_length (last_block.index)}
    # Compare all with own chain length
    # Make GenServer call to longest chain node
    # Set highest as current_chain

    # prev_block = Enum.at(current_chain, 0)
    prev_block = get_last_block(current_map.chain)

    # Initializations
    curr_index = prev_block.index + 1
    curr_tx = transaction
    curr_prev_hash = prev_block.hash
    curr_timestamp = System.system_time(:second)

    {curr_nonce, curr_hash} =
      find_nonce_and_hash(curr_index, curr_tx, curr_prev_hash, curr_timestamp, 0)

    # Make block
    curr_block = %{
      :index => curr_index,
      :nonce => curr_nonce,
      # :coinbase => [],
      :difficulty => 0,
      :tx => curr_tx,
      :prev_hash => curr_prev_hash,
      :time_stamp => curr_timestamp,
      :hash => curr_hash
    }

    # Add block to local chain
    {_, current_map} = Map.get_and_update(current_map, :chain, fn x -> {x, [curr_block | x]} end)
    {:noreply, current_map}

    # TODO: send the updated chain to all nodes in the system. 
  end

  # Print state for debugging
  def handle_cast({:print_state}, current_map) do
    IO.inspect(current_map)
    {:noreply, current_map}
  end

  def handle_cast({:verify}, current_map) do
    verify_blockchain(current_map.chain)
    {:noreply, current_map}
  end

  # Return Nonce and hexadecimal hash
  defp find_nonce_and_hash(index, tx, prev_hash, time_stamp, nonce) do
    ip =
      Integer.to_string(index) <>
        tx <> prev_hash <> Integer.to_string(nonce) <> Integer.to_string(time_stamp)

    hex_hash = :crypto.hash(:sha, ip) |> Base.encode16()
    {int_hash, _} = hex_hash |> Integer.parse(16)

    {nonce, hex_hash} =
      if rem(int_hash, 2) == 0 do
        {nonce, hex_hash}
      else
        find_nonce_and_hash(index, tx, prev_hash, time_stamp, nonce + 1)
      end
  end

  # Return hexadecimal hash
  defp get_hash(index, tx, prev_hash, time_stamp, nonce) do
    ip =
      Integer.to_string(index) <>
        tx <> prev_hash <> Integer.to_string(nonce) <> Integer.to_string(time_stamp)

    hex_hash = :crypto.hash(:sha, ip) |> Base.encode16()
  end

  # Return last block of the blockchain
  defp get_last_block(chain) do
    Enum.at(chain, 0)
  end

  # Verify if blockchain is valid
  defp verify_blockchain(chain) do
    # Verify linked list
    invalid_chain =
      0..(length(chain) - 2)
      |> Enum.to_list()
      |> Enum.map(fn x ->
        if Enum.at(chain, x).prev_hash != Enum.at(chain, x + 1).hash, do: x, else: nil
      end)
      |> Enum.filter(fn x -> x != nil end)

    # Verify individual hashes
    invalid_hash_blocks =
      Enum.filter(chain, fn x ->
        x.hash != get_hash(x.index, x.tx, x.prev_hash, x.time_stamp, x.nonce)
      end)

    IO.inspect(length(invalid_hash_blocks) == 0 and length(invalid_chain) == 0)

    length(invalid_hash_blocks) == 0 and length(invalid_chain) == 0
  end

  # CAST EXAMPLE 
  # def handle_cast({:print_state}, current_map) do
  #   IO.inspect(current_map)
  #   {:noreply, current_map}
  # end

  # CALL EXAMPLE
  # def handle_call(:get_predecessor, _from, current_map) do
  #   {:reply, current_map.predecessor, current_map}
  # end

  # PERIODIC INVOKE EXAMPLE
  # def handle_info(:fix_finger_table, current_map) do

  #   periodic_fix_fingers()

  #   {:noreply, updated_map}
  # end

  # defp periodic_fix_fingers() do
  #   # if Process.alive?(self()) != nil do
  #     Process.send_after(self(), :fix_finger_table, 10_000)
  #   # end
  # end
end
