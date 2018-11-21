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
        :neighbours => []
      },
      name: input_name
    )
  end

  # Genserver Implementation
  def init(initial_map) do
    {:ok, initial_map}
  end

  # Returns a tuple {are_inputs_valid?, balance}
  # are_inputs_valid? is a boolean 
  # balance is a float (amounts in referred transactions - amount to send)
  # transaction_ip is of the form [%{:hash => txid, :n => index of the transaction}]
  defp are_inputs_valid_and_difference(sender, amount, chain, transaction_ips) do

    # VERIFY INPUTS
    # 1. Check if the sender was the receiver in those transactions
    # 2. Check if sum of all those amounts >= amount

    # List of txids from transaction_ips that we have to find
    txids_to_find = 
      transaction_ips
        |> Enum.map(fn x -> x.hash end)

    # Anonymous functions for filtering in the comprehensions
    ele_in_txids_to_find? = &(&1 in txids_to_find)
    # receiver_matching? = &(Atom.to_string(&1) == String.slice(sender, 1..-1))
    receiver_matching? = &(&1 == sender)

    # List of amounts in the referenced transactions
    amounts_to_sender_in_ip_transactions =
      for block <- chain,
        tx_in_block <- block.tx, ele_in_txids_to_find?.(tx_in_block.txid),
          tx_out <- tx_in_block.out, receiver_matching?.(tx_out.receiver),
            ip_to_find <- transaction_ips, ele_in_txids_to_find?.(ip_to_find.hash)
          do
            # Check index
            if tx_out.n == ip_to_find.n do
              # return amount in this transaction
              tx_out.amount
            end
          end

      # IO.inspect Enum.sum(amounts_to_sender_in_ip_transactions)
      
      # Sum all the amounts in referenced transaction and compare to amount being sent.
      are_inputs_valid? = Enum.sum(amounts_to_sender_in_ip_transactions) >= String.to_float(amount)
      
      IO.inspect are_inputs_valid?

      if are_inputs_valid? do
        {are_inputs_valid?, Enum.sum(amounts_to_sender_in_ip_transactions) - String.to_float(amount)}
      else
        {are_inputs_valid?, 0.0}
      end
  end

  # Take input as a space separated string of the form "Sender Receiver Amount"
  # Transaction_ips is a list of transactions to use as input for this transaction
  # transaction_ip is of the form [%{:hash => txid, :n => index of the transaction}]
  def handle_cast({:make_transaction, ip_string, transaction_ips}, current_map) do

    # Split the input string
    # h1 h2 100.0
    [sender, receiver, amount] = String.split(ip_string)

    # 1. Check if inputs are valid
    # 2. Find the change address
    # 3. Add this change address to the transaction
    # 4. Find overall hash of the transaction (For all individual parts)
    # 5. Send to {:add_transaction}

    {are_inputs_valid?, balance} =
     are_inputs_valid_and_difference(sender, amount, current_map.chain, transaction_ips)

    # # Make transaction
    transaction = 
      %{
        # Format for :in => [%{:hash, :n}, ...]
        :in => transaction_ips,

        :out => [
          %{
          :sender => sender,
          :receiver => receiver,
          :amount => String.to_float(amount),
          :n => 0,
          }
        ],

        :txid => :crypto.hash(:sha, sender <> receiver <> amount) |> Base.encode16(),
      }

    # Add change address to transaction
    transaction =
      add_change_address_to_transaction(transaction, balance, sender)
    
    find_overall_hash_of_transaction()

    IO.inspect transaction
    
    GenServer.cast(self(), {:add_transaction, transaction})

    {:noreply, current_map}
  end

  # Adds a transaction to the front of the local uncommitted transaction list if valid
  # Also will start the transaction gossip
  def handle_cast({:add_transaction, transaction}, current_map) do
    # Check if transaction is valid
    if check_if_transaction_valid(transaction) do

      check_signature()
      check_if_double_spend()

      # Add to local uncommitted transactions
      {_, current_map} =
        Map.get_and_update(current_map, :uncommitted_transactions, fn x ->
          {x, [transaction | x]}
        end)

      # Start gossip
      # Send to 8 random neighbours

      current_map.neighbours
      |> Enum.take_random(8)
      |> Enum.map(&GenServer.cast(&1, {:gossip_transaction, transaction}))
    end
    {:noreply, current_map}
  end

  def handle_cast({:mine}, current_map) do
    
    # Last block in the chain is at index 0 (We are adding to the front of the chain)
    prev_block = Enum.at(current_map.chain, 0)

    # Initializations
    curr_index = prev_block.index + 1
    curr_prev_hash = prev_block.hash
    curr_time = System.system_time(:second)

    curr_tx =
      get_list_highest_priority_uncommitted_transactions(current_map.uncommitted_transactions)

    # Remove from uncommitted transactions
    {_, current_map} =
      remove_transactions_from_uncommitted_transactions(curr_tx, current_map) 
    
    # Make coinbase transaction and add to curr_tx
    curr_tx =
      add_coinbase_transaction(current_map.public_key, curr_tx)

    {curr_mrkl_root, curr_mrkl_tree} = get_mrkl_tree_and_root(curr_tx)

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
      :difficulty => 1
    }

    # Add block to local chain
    {_, current_map} = Map.get_and_update(current_map, :chain, fn x -> {x, [curr_block | x]} end)

    # Start gossip
    # Send to 8 random neighbours

    current_map.neighbours
    |> Enum.take_random(8)
    |> Enum.map(&(GenServer.cast(&1, {:gossip_block, curr_block})))

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
  #  GOSSIP
  # ----------------------------------------------------------------------------------------------

  # Append to neighbours list
  def handle_cast({:set_neighbours, lst_neighbours}, current_map) do
    {_, current_map} =
      Map.get_and_update(current_map, :neighbours, fn x -> {x, x ++ lst_neighbours} end)

    {:noreply, current_map}
  end

  # Gossip transaction. Can combine with {:add_transaction} in the end if necessary
  def handle_cast({:gossip_transaction, transaction}, current_map) do
    {should_propagate, current_map} =
      if not Enum.member?(current_map.uncommitted_transactions, transaction) do
        check_if_transaction_valid(transaction)
        check_if_double_spend()

        # Add to uncommitted transactions
        {_, map_to_return} =
          Map.get_and_update(current_map, :uncommitted_transactions, fn x ->
            {x, [transaction | x]}
          end)

        # {should_propagate, current_map}
        {true, map_to_return}
      else
        # {should_propagate, current_map}
        {false, current_map}
      end

    if should_propagate do
      # Send to 8 random neighbours

      current_map.neighbours
      |> Enum.take_random(8)
      |> Enum.each(fn x -> GenServer.cast(x, {:gossip_transaction, transaction}) end)
    end

    {:noreply, current_map}
  end

  # Gossip the block to 8 other neighbours
  def handle_cast({:gossip_block, block}, current_map) do
    
    is_new_block = not Enum.member?(current_map.chain, block)

    builds_on_curr_longest =
      if Enum.at(current_map.chain, 0).index + 1 == block.index, do: true, else: false

    {should_propagate, current_map} =
    
    # TODO: Handle forks
      # 1. Store forks
      # 2. Choose the higher nonce one for mining next
      # 3. after 6 deep, discard fork
      
      # 1. Is this a new block?
      # 2. Is the block valid?
      # 3. Are all the transactions in this block valid? (Check double spends also here)
      # 4. Builds on the current known longest chain? (to avoid forks)

      if is_new_block and verify_block_hash(block) and check_if_all_transactions_valid(block) and builds_on_curr_longest do

        # Add to local blockchain
        {_, map_to_return} =
        Map.get_and_update(current_map, :chain, fn x ->
          {x, [block | x]}
        end)
        
        # Remove from uncommitted transactions
        {_, map_to_return} =
          remove_transactions_from_uncommitted_transactions(block.tx, map_to_return)

        # {should_propagate, current_map}
        {true, map_to_return}
      else
        # {should_propagate, current_map}
        {false, current_map}
      end
      
      if should_propagate do
        # Send to 8 random neighbours
        current_map.neighbours
        |> Enum.take_random(8)
        |> Enum.each(fn x -> GenServer.cast(x, {:gossip_block, block}) end)
      end

    {:noreply, current_map}
  end 

  # ----------------------------------------------------------------------------------------------
  #  PRIVATE UTILITY METHODS
  # ----------------------------------------------------------------------------------------------

  # Return Nonce and hexadecimal hash
  defp find_nonce_and_hash(index, prev_hash, time, mrkl_root, nonce) do
    hex_hash = get_hash(index, prev_hash, time, mrkl_root, nonce)

    # Check if first digit is zero 
    {nonce, hex_hash} =
      if String.slice(hex_hash, 0, 1) == "0" do
        {nonce, hex_hash}
      else
        find_nonce_and_hash(index, prev_hash, time, mrkl_root, nonce + 1)
      end
  end

  # Return hexadecimal hash
  defp get_hash(index, prev_hash, time, mrkl_root, nonce) do
    ip =
      Integer.to_string(index) <>
        prev_hash <> Integer.to_string(time) <> mrkl_root <> Integer.to_string(nonce)

    hex_hash = :crypto.hash(:sha, ip) |> Base.encode16()
  end

  defp verify_block_hash(block) do
    # Check if incoming block is valid
    if get_hash(block.index, block.prev_hash, block.time, block.mrkl_root, block.nonce) == block.hash do
      true
    else
      false
    end
  end

  # Verify if blockchain is valid
  defp verify_blockchain(chain) do
    # Verify linked list
    invalid_chain =
      0..(length(chain) - 2)
      # |> Enum.to_list()
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

  defp verify_merkleTree() do
    
  end

  defp add_coinbase_transaction(public_key, curr_tx) do

    coinbase = 
      %{
        # Format for :in => [%{:hash, :n}, ...]
        :in => [
          %{
            :hash => 000000000,
            :n => 0,
          }
        ],

        :out => [
          %{
          :sender => "coinbase",
          :receiver =>  Atom.to_string(public_key),
          :amount => 25.0,
          :n => 0,
          }
        ],

        :txid => :crypto.hash(:sha, "coinbase" <> Atom.to_string(public_key) <> "25.0") |> Base.encode16(),
      }
    
    [coinbase | curr_tx]
  end

  defp get_list_highest_priority_uncommitted_transactions(lst_uncommitted_transactions) do
    # TODO: Return transactions according to the fees here
    lst_uncommitted_transactions
  end

  defp get_mrkl_tree_and_root(lst_tx) do
    # TODO: Implement Merkle Tree

    # # if length is not even
    # if length(lst_tx) |> rem(2) !=0 do
    #   lst_tx ++ List.last(lst_tx)
    # end 
      
    # lst_of_list=Enum.chunk_every(lst_tx,2)

    
    # lst_of_list=Enum.map(lst_of_list, fn [x,y] -> :crypto.hash(:sha256,x) + :crypto.hash(:sha256,x) )

    hashed = MerkleTreeNode.build(lst_tx)
    
    {hashed.value, hashed}
  end

  defp check_if_transaction_valid(transaction_map) do
    # TODO: Implement this
    # :crypto.hash(:sha, transaction_map.sender <> transaction_map.receiver <> Float.to_string(transaction_map.amount))
    #  |> Base.encode16() == transaction_map.txid
    true 
  end

  defp check_if_double_spend() do
    # TODO: Implement this
  end

  defp check_if_all_transactions_valid(block) do
    # TODO: Implement this

    # Return true for now because this is being used in mine method
    true
    # Foreach transaction in block call check_if_transaction_valid()
  end

  defp check_signature() do
    # TODO: Implement this
  end

  defp remove_transactions_from_uncommitted_transactions(tx_to_remove, current_map) do

    new_uncommitted = Enum.filter(current_map.uncommitted_transactions, fn x -> x not in tx_to_remove end)
    Map.get_and_update(current_map, :uncommitted_transactions, fn x -> {x, new_uncommitted} end)
  end

  # Add change address to the transaction output with given balance
  # Assign index to the change address
  # balance is float
  # sender is string
  defp add_change_address_to_transaction(transaction, balance, sender) do

    # TODO: Implement this

    # Format for transaction is as follows
    # transaction = 
    #   %{
    #     # Format for :in => [%{:hash, :n}, ...]
    #     :in => transaction_ips,

    #     :out => [
    #       %{
    #       :sender => sender,
    #       :receiver => receiver,
    #       :amount => String.to_float(amount),
    #       :n => 0,
    #       }
    #     ],

    #     :txid => :crypto.hash(:sha, sender <> receiver <> amount) |> Base.encode16(),
    #   }

    ip_out = transaction.out
    n_to_assign = length(ip_out)

    change_address = 
      %{
        :sender => sender,
        :receiver => sender,
        :amount => balance,
        :n => n_to_assign,
      }

      ip_out = [change_address | ip_out]
    {_, transaction} = 
      Map.get_and_update(transaction, :out, fn x -> {x, ip_out} end)
    
    transaction
  end

  defp find_overall_hash_of_transaction() do
    # TODO: Implement this
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

# GenServer.cast(:B1D5781111D84F7B3FE45A0852E59758CD7A87E5, {:make_transaction,"B1D5781111D84F7B3FE45A0852E59758CD7A87E5 AC3478D69A3C81FA62E60F5C3696165A4E5E6AC4 10.0"  , [ %{ :hash => "567E353A9DF286023A5214C5A2B7B5C70B971C64", :n => 0 }]})
# GenServer.cast(:DA4B9237BACCCDF19C0760CAB7AEC4A8359010B0,{:mine})