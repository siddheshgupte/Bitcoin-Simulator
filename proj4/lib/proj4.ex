defmodule Proj4 do
  use GenServer, restart: :temporary

  @type tx_in_t :: %{hash: String.t(), n: integer}
  @type tx_out_t :: %{sender: String.t(), receiver: String.t(), amount: float, n: integer}
  @type tx_t :: %{in: [tx_in_t], out: [tx_out_t], txid: String.t(), signature: String.t}
  @type block_t :: %{
          index: integer,
          hash: String.t(),
          prev_hash: String.t(),
          time: integer,
          nonce: integer,
          mrkl_root: String.t(),
          n_tx: integer,
          tx: [tx_t],
          mrkl_tree: any,
          difficulty: integer
        }

  # External API
  def start_link([input_name, private_key, genesis_block]) do
    GenServer.start_link(
      __MODULE__,
      %{
        :public_key => input_name,
        :private_key => private_key,
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

  # Take input as a space separated string of the form "Sender Receiver Amount"
  # Transaction_ips is a list of transactions to use as input for this transaction
  # transaction_ip is of the form [%{:hash => txid, :n => index of the transaction}, ...]
  @spec handle_cast({:make_transaction, String.t(), [tx_in_t]}, map) :: {:noreply, map}
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
    transaction = %{
      # Format for :in => [%{:hash, :n}, ...]
      :in => transaction_ips,
      :out => [
        %{
          :sender => sender,
          :receiver => receiver,
          :amount => String.to_float(amount),
          :n => 0
        }
      ],
      :txid => "Placeholder",
      :signature => "Placeholder",
    }

    # Add change address and set overall hash of transaction 
    # Do this only if inputs are valid 
    transaction =
      if are_inputs_valid? do
        transaction
        # Add change address to transaction
        |> add_change_address_to_transaction(balance, sender)
        # Set overall hash of the transaction
        |> find_and_set_overall_hash_of_transaction()
        # Set signature
        # TODO: Change this to private key of the person doing the transaction
        |> set_signature_of_transaction(current_map.private_key)
      end

    # If this is a valid transaction, send to {:add_transaction} which will then gossip to other nodes
    if are_inputs_valid? do
      GenServer.cast(self(), {:add_transaction, transaction})
    end

    {:noreply, current_map}
  end

  # Adds a transaction to the front of the local uncommitted transaction list if valid
  # Also will start the transaction gossip
  @spec handle_cast({:add_transaction, tx_t}, map) :: {:noreply, map}
  def handle_cast({:add_transaction, transaction}, current_map) do

    # 1. Check if transaction's hash is valid
    # 2. Check if transaction is a double spend
    # 3. Check the signature of the transaction

    # Check if transaction is valid and not a double spend
    if check_if_transaction_valid(transaction)
    and is_not_double_spend?(transaction, current_map.uncommitted_transactions, current_map.chain)
    and check_signature(transaction, current_map.public_key) do
      IO.inspect check_signature(transaction, current_map.public_key)
      
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
    current_map = remove_transactions_from_uncommitted_transactions(curr_tx, current_map)

    # Make coinbase transaction and add to curr_tx
    curr_tx = add_coinbase_transaction(current_map.public_key, curr_tx)

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
    |> Enum.map(&GenServer.cast(&1, {:gossip_block, curr_block}))

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
  @spec handle_cast({:set_neighbours, [atom]}, map) :: {:noreply, map}
  def handle_cast({:set_neighbours, lst_neighbours}, current_map) do
    {_, current_map} =
      Map.get_and_update(current_map, :neighbours, fn x -> {x, x ++ lst_neighbours} end)

    {:noreply, current_map}
  end

  # Gossip transaction. Can combine with {:add_transaction} in the end if necessary
  @spec handle_cast({:gossip_transaction, tx_t}, map) :: {:noreply, map}
  def handle_cast({:gossip_transaction, transaction}, current_map) do
    # Don't propagate if
    # 1. This transaction already exists in uncommitted
    # 2. Transaction isn't valid for it's hash
    # 3. Inputs of the transaction aren't valid
    # 4. Is a double spend wrt already seen transactions - take the input and check uncommitted + all blockchain transactions inputs 

    {should_propagate, current_map} =
      if not Enum.member?(current_map.uncommitted_transactions, transaction) and
           check_if_transaction_valid(transaction) and
           inputs_of_transaction_valid?(transaction, current_map) and
           is_not_double_spend?(transaction, current_map.uncommitted_transactions, current_map.chain) do

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
  @spec handle_cast({:gossip_block, block_t}, map) :: {:noreply, map}
  def handle_cast({:gossip_block, block}, current_map) do
    is_new_block = not Enum.member?(current_map.chain, block)

    builds_on_curr_longest = Enum.at(current_map.chain, 0).index + 1 == block.index

    # TODO: Handle forks
    # 1. Store forks
    # 2. Choose the higher nonce one for mining next
    # 3. after 6 deep, discard fork

    # VERIFY BLOCK
    # 1. Is this a new block?
    # 2. Is the block valid?
    # 3. Are all the transactions in this block valid? (Check double spends also here?)
    # 4. Builds on the current known longest chain? (to avoid forks)
    {should_propagate, current_map} =
      if is_new_block and verify_block_hash(block) and check_if_all_transactions_valid(block) and
           builds_on_curr_longest do
        # Add to local blockchain
        {_, map_to_return} =
          Map.get_and_update(current_map, :chain, fn x ->
            {x, [block | x]}
          end)

        # Remove from uncommitted transactions
        map_to_return = remove_transactions_from_uncommitted_transactions(block.tx, map_to_return)

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

  # Returns a tuple {are_inputs_valid?, balance}
  # balance is (amounts in referred transactions - amount to send)
  # transaction_ip is of the form [%{:hash => txid, :n => index of the transaction}]
  @spec are_inputs_valid_and_difference(String.t(), String.t(), list, [tx_in_t]) ::
          {boolean, float}
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
    receiver_matching? = &(&1 == sender)

    # List of amounts in the referenced transactions
    amounts_to_sender_in_ip_transactions =
      for block <- chain,
          tx_in_block <- block.tx,
          ele_in_txids_to_find?.(tx_in_block.txid),
          tx_out <- tx_in_block.out,
          receiver_matching?.(tx_out.receiver),
          ip_to_find <- transaction_ips,
          ele_in_txids_to_find?.(ip_to_find.hash) do
        # Check index
        if tx_out.n == ip_to_find.n do
          # return amount in this transaction
          tx_out.amount
        end
      end

    # Sum all the amounts in referenced transaction and compare to amount being sent.
    are_inputs_valid? = Enum.sum(amounts_to_sender_in_ip_transactions) >= String.to_float(amount)

    if are_inputs_valid? do
      {are_inputs_valid?,
       Enum.sum(amounts_to_sender_in_ip_transactions) - String.to_float(amount)}
    else
      {are_inputs_valid?, 0.0}
    end
  end

  # Return Nonce and hexadecimal hash
  @spec find_nonce_and_hash(integer, String.t(), integer, String.t(), integer) ::
          {integer, String.t()}
  defp find_nonce_and_hash(index, prev_hash, time, mrkl_root, nonce) do
    hex_hash = get_hash(index, prev_hash, time, mrkl_root, nonce)

    # Check if first digit is zero 
    if String.slice(hex_hash, 0, 1) == "0" do
      {nonce, hex_hash}
    else
      find_nonce_and_hash(index, prev_hash, time, mrkl_root, nonce + 1)
    end
  end

  # Return hexadecimal hash
  @spec get_hash(integer, String.t(), integer, String.t(), integer) :: String.t()
  defp get_hash(index, prev_hash, time, mrkl_root, nonce) do
    ip =
      Integer.to_string(index) <>
        prev_hash <> Integer.to_string(time) <> mrkl_root <> Integer.to_string(nonce)

    :crypto.hash(:sha, ip) |> Base.encode16()
  end

  @spec verify_block_hash(block_t) :: boolean
  defp verify_block_hash(block) do
    # Check if incoming block is valid
    get_hash(block.index, block.prev_hash, block.time, block.mrkl_root, block.nonce) == block.hash
  end

  # Verify if blockchain is valid
  @spec verify_blockchain([block_t]) :: boolean
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

    IO.inspect length(invalid_hash_blocks) == 0 and length(invalid_chain) == 0
  end

  @spec add_coinbase_transaction(atom, [tx_t]) :: [tx_t]
  defp add_coinbase_transaction(public_key, curr_tx) do
    coinbase = %{
      # Format for :in => [%{:hash, :n}, ...]
      :in => [
        %{
          :hash => "000000000",
          :n => 0
        }
      ],
      :out => [
        %{
          :sender => "coinbase",
          :receiver => Atom.to_string(public_key),
          :amount => 25.0,
          :n => 0
        }
      ],
      :txid =>
        :crypto.hash(:sha, "coinbase" <> Atom.to_string(public_key) <> "25.0") |> Base.encode16()
    }

    [coinbase | curr_tx]
  end

  @spec get_list_highest_priority_uncommitted_transactions([tx_t]) :: [tx_t]
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

  # Finds the combined hash for all the transactions in a transaction
  @spec get_hash_for_transaction(tx_t) :: String.t()
  defp get_hash_for_transaction(transaction) do
    # Collect all senders in a list
    senders =
      for tx <- transaction.out,
          do: tx.sender

    # Collect all receivers in a list
    receivers =
      for tx <- transaction.out,
          do: tx.receiver

    # Collect all amounts in a list
    amounts =
      for tx <- transaction.out,
          do: tx.amount

    # Sort each and combine into one string each 
    senders = senders |> Enum.sort() |> Enum.join("")
    receivers = receivers |> Enum.sort() |> Enum.join("")
    amounts = amounts |> Enum.sort() |> Enum.join("")

    # return calculated hash
    :crypto.hash(:sha, senders <> receivers <> amounts) |> Base.encode16()
  end

  @spec check_if_transaction_valid(tx_t) :: boolean
  defp check_if_transaction_valid(transaction) do
    txid_calculated = get_hash_for_transaction(transaction)
    txid_calculated == transaction.txid
  end

  @spec is_not_double_spend?(tx_t, [tx_t], [block_t]) :: boolean
  defp is_not_double_spend?(transaction, uncommitted_transactions, chain) do

    # 1. Check in uncommitted transactions if the input is equal to the inputs given here
    # 2. Check all blocks' transactions inputs to check if input is equal to the inputs given here 

    results = 
    for uc_tx <- uncommitted_transactions,
      input <- uc_tx.in
      do
        input in transaction.in 
      end

    uncommitted_not_double_spent = Enum.filter(results, fn x -> x != false end) |> length() == 0
    
    chain_not_double_spent = 
      if uncommitted_not_double_spent do

        results = 
          for block <- chain,
            tx <- block.tx,
              input <- tx.in
              do
                input in transaction.in
              end
        
        Enum.filter(results, fn x -> x != false end) |> length() == 0
      else
        # false
        uncommitted_not_double_spent
      end
    
    uncommitted_not_double_spent and chain_not_double_spent
  end

  @spec check_if_all_transactions_valid(block_t) :: boolean
  defp check_if_all_transactions_valid(block) do
    # For each transaction in block call check_if_transaction_valid()

    invalid_transactions =
      block.tx
      # Check which elements return false for check_if_transaction_valid 
      |> Enum.filter(fn tx -> not check_if_transaction_valid(tx) end)

    # Return true for now because this is being used in mine method
    length(invalid_transactions) == 0
  end

  defp check_signature(transaction, public_key) do
    {_, signature} = transaction.signature |> Base.decode16
    {_, public_key} = public_key |> Atom.to_string() |> Base.decode16

    :crypto.verify(:ecdsa, :sha256, transaction.txid, signature, [public_key, :secp256k1])
  end

  @spec remove_transactions_from_uncommitted_transactions([tx_t], map) :: map
  defp remove_transactions_from_uncommitted_transactions(tx_to_remove, current_map) do
    new_uncommitted =
      Enum.filter(current_map.uncommitted_transactions, fn x -> x not in tx_to_remove end)

    {_, map_to_return} =
      Map.get_and_update(current_map, :uncommitted_transactions, fn x -> {x, new_uncommitted} end)

    map_to_return
  end

  # Add change address to the transaction output with given balance
  # Assign index to the change address
  @spec add_change_address_to_transaction(map, float, String.t()) :: tx_t
  defp add_change_address_to_transaction(transaction, balance, sender) do
    ip_out = transaction.out
    n_to_assign = length(ip_out)

    change_address = %{
      :sender => sender,
      :receiver => sender,
      :amount => balance,
      :n => n_to_assign
    }

    ip_out = [change_address | ip_out]
    {_, transaction} = Map.get_and_update(transaction, :out, fn x -> {x, ip_out} end)

    transaction
  end

  @spec find_and_set_overall_hash_of_transaction(tx_t) :: tx_t
  defp find_and_set_overall_hash_of_transaction(transaction) do

    txid_to_set = get_hash_for_transaction(transaction)

    {_, transaction} = Map.get_and_update(transaction, :txid, fn x -> {x, txid_to_set} end)

    # Return updated map with the new hash
    transaction
  end

  # Check if inputs of the transaction are valid
  # This checks it for all the transactions in the transaction.out
  # i.e calls are_inputs_valid_and_difference() for all transactions in transaction.out
  @spec inputs_of_transaction_valid?(tx_t, map) :: boolean
  defp inputs_of_transaction_valid?(transaction, current_map) do
    # Anonymous function for filtering out change addresses
    sender_not_eq_receiver? = fn x -> x.sender != x.receiver end

    # Collect results of are_inputs_valid_and_difference for all txs in tx_out.
    # results is of the format [{true, 10.0}, ...]
    results =
      for tx_out <- transaction.out,
          sender_not_eq_receiver?.(tx_out),
          do:
            are_inputs_valid_and_difference(
              tx_out.sender,
              Float.to_string(tx_out.amount),
              current_map.chain,
              transaction.in
            )

    # Check the collected results for a non valid transaction i.e check for {false, amount}
    non_valid_inputs = for {false, n} <- results, do: n

    # If there are no invalid inputs, then return true
    length(non_valid_inputs) == 0
  end

  @spec set_signature_of_transaction(tx_t, String.t) :: tx_t 
  defp set_signature_of_transaction(transaction, private_key) do
    signature = :crypto.sign(:ecdsa, :sha256, transaction.txid, [private_key, :secp256k1]) |> Base.encode16()
    {_, transaction} = Map.get_and_update(transaction, :signature, fn x -> {x, signature} end)
    transaction
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

# GenServer.cast(:"0441920A72D0B2F76C2D5DB39E034060C38B12B07F99DFCDD6063888312818DF15FC78834C3FE49EBB32B1E7DB540D08A3E07FA8C1D05D3C43A848BE8C8BFCCCA1", {:make_transaction,"0441920A72D0B2F76C2D5DB39E034060C38B12B07F99DFCDD6063888312818DF15FC78834C3FE49EBB32B1E7DB540D08A3E07FA8C1D05D3C43A848BE8C8BFCCCA1 048BC7CF874FDFBA95B765BC803D4003BBF4E98081F854D5975DF2E528A336D0726AD5E859A4D9562602C0E29D620834D6510071C7DB21A99ABFEF0F10B637A4C9 10.0"  , [ %{ :hash => "8A12EB159B4EE7320FE4FF04F6C1088D5A8F078A", :n => 0 }]})
# GenServer.cast(:"04EFEB65F418AB164360A5C51A6AA3A8B8B56150F21D6067EAA2C1E0F7FFAFCE472ECAEE94F4CFDF6E8EBCADB3A17C4D584EEFF0E076C9333383651EFEC0C29FFA",{:mine})
