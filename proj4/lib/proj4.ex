defmodule Proj4 do
  use GenServer, restart: :temporary

  # External API
  def start_link([input_name, genesis_block]) do
    GenServer.start_link(
      __MODULE__,
      %{
        :public_key => input_name,
        :chain => genesis_block,
        :uncommitted_transactions => [],
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

  def handle_cast({:mine}, current_map) do
    # Implement consensus
    # Make every node send {self.pid, chain_length (last_block.index)}
    # Compare all with own chain length
    # Make GenServer call to longest chain node
    # Set highest as current_chain

    # Last block in the chain is at index 0 (We are adding to the front of the chain)
    prev_block = Enum.at(current_map.chain, 0)

    # Initializations
    curr_index = prev_block.index + 1
    curr_prev_hash = prev_block.hash
    curr_time = System.system_time(:second)

    curr_tx = get_list_highest_priority_uncommitted_transactions(current_map.uncommitted_transactions)

    {curr_mrkl_root, curr_mrkl_tree} =
       get_mrkl_tree_and_root(curr_tx)
    
    {curr_nonce, curr_hash} =
      find_nonce_and_hash(curr_index, curr_prev_hash, curr_time, curr_mrkl_root, 0)

    # Make block
    curr_block = %{

      # Header
      :index => curr_index,
      :hash => curr_hash,
      :prev_hash => curr_prev_hash,
      :time => curr_time,
      :nonce => curr_nonce,
      
      # Transaction Data
      :mrkl_root => curr_mrkl_root,
      :n_tx => length(curr_tx),
      :tx => curr_tx,
      :mrkl_tree => curr_mrkl_tree,
      :difficulty => 1,
    }

    # Add block to local chain
    {_, current_map} = Map.get_and_update(current_map, :chain, fn x -> {x, [curr_block | x]} end)

    # TODO: send the updated chain to all nodes in the system. 
    {:noreply, current_map}
  end

  # Print state for debugging
  def handle_cast({:print_state}, current_map) do
    IO.inspect(current_map)
    {:noreply, current_map}
  end

  # Verify the entire chain
  def handle_cast({:full_verify}, current_map) do
    verify_blockchain(current_map.chain)
    {:noreply, current_map}
  end

  # ----------------------------------------------------------------------------------------------
  #  PRIVATE UTILITY METHODS
  # ----------------------------------------------------------------------------------------------
  
  # Return Nonce and hexadecimal hash
  defp find_nonce_and_hash(index, prev_hash, time, mrkl_root, nonce) do
    
    hex_hash =
      get_hash(index, prev_hash, time, mrkl_root, nonce)

    {nonce, hex_hash} =
      # Check if first digit is zero 
      if String.slice(hex_hash, 0, 1) == "0" do
        {nonce, hex_hash}
      else
        find_nonce_and_hash(index, prev_hash, time, mrkl_root, nonce + 1)
      end
  end

  # Return hexadecimal hash
  defp get_hash(index, prev_hash, time, mrkl_root, nonce) do
    ip =
      Integer.to_string(index) <> prev_hash <> Integer.to_string(time) <> mrkl_root <> Integer.to_string(nonce) 

    hex_hash = :crypto.hash(:sha, ip) |> Base.encode16()
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
        x.hash != get_hash(x.index, x.prev_hash, x.time, x.mrkl_root, x.nonce)
      end)

    IO.inspect(length(invalid_hash_blocks) == 0 and length(invalid_chain) == 0)

    length(invalid_hash_blocks) == 0 and length(invalid_chain) == 0
  end

  defp get_list_highest_priority_uncommitted_transactions(lst_uncommitted_transactions) do
    # TODO: Return transactions according to the fees here
    lst_uncommitted_transactions
  end

  defp get_mrkl_tree_and_root(lst_tx) do
    # TODO: Implement Merkle Tree
    hashed = :crypto.hash(:sha, Enum.at(lst_tx, 0)) |> Base.encode16()
    {hashed, hashed}
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
