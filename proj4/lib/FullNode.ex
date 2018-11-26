defmodule FullNode do
  @moduledoc """
    This module implements a full node - i.e node that can mine and holds the entire chain.
  """
  use GenServer, restart: :temporary
  import UtilityFn, only: :functions

  @type tx_in_t :: %{hash: String.t(), n: integer}
  @type tx_out_t :: %{sender: String.t(), receiver: String.t(), amount: float, n: integer}
  @type tx_t :: %{in: [tx_in_t], out: [tx_out_t], txid: String.t(), signature: String.t()}
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
     #   :private_key => private_key,
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
    UtilityFn.are_inputs_valid_and_difference(sender, amount, current_map.chain, transaction_ips)

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
      :signature => "Placeholder"
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
    if UtilityFn.check_if_transaction_valid(transaction) and
    UtilityFn.is_not_double_spend?(
           transaction,
           current_map.uncommitted_transactions,
           current_map.chain
         ) and UtilityFn.check_signature(transaction, current_map.public_key) do
      IO.inspect(UtilityFn.check_signature(transaction, current_map.public_key))

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
    UtilityFn.get_list_highest_priority_uncommitted_transactions(current_map.uncommitted_transactions)

    # Remove from uncommitted transactions
    current_map = UtilityFn.remove_transactions_from_uncommitted_transactions(curr_tx, current_map)

    # Make coinbase transaction and add to curr_tx
    curr_tx = UtilityFn.add_coinbase_transaction(current_map.public_key, curr_tx)

    {curr_mrkl_root, curr_mrkl_tree} = UtilityFn.get_mrkl_tree_and_root(curr_tx)

    {curr_nonce, curr_hash} =
    UtilityFn.find_nonce_and_hash(curr_index, curr_prev_hash, curr_time, curr_mrkl_root, 0)

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
  def handle_call({:full_verify}, current_map) do
    verify_blockchain(current_map.chain)
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
    # 2. Signature isn't valid
    # 3. Transaction isn't valid for it's hash
    # 4. Inputs of the transaction aren't valid
    # 5. Is a double spend wrt already seen transactions - take the input and check uncommitted + all blockchain transactions inputs 

    sender_public_key_atom = UtilityFn.get_sender_from_transaction(transaction) |> String.to_atom

    {should_propagate, current_map} =
      if not Enum.member?(current_map.uncommitted_transactions, transaction) and
      UtilityFn.check_signature(transaction, sender_public_key_atom) and
      UtilityFn.check_if_transaction_valid(transaction) and
      UtilityFn.inputs_of_transaction_valid?(transaction, current_map) and
      UtilityFn.is_not_double_spend?(
             transaction,
             current_map.uncommitted_transactions,
             current_map.chain
           ) do
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
    IO.inspect(block)

    {should_propagate, current_map} =
      if is_new_block and UtilityFn.verify_block_hash(block) and UtilityFn.check_if_all_transactions_valid(block) and
           builds_on_curr_longest do
        # Add to local blockchain
        {_, map_to_return} =
          Map.get_and_update(current_map, :chain, fn x ->
            {x, [block | x]}
          end)

        # Remove from uncommitted transactions
        map_to_return = UtilityFn.remove_transactions_from_uncommitted_transactions(block.tx, map_to_return)

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

  def handle_call({:get_required_blocks, transaction_ips}, _from, current_map) do
    txids_to_find =
      transaction_ips
      |> Enum.map(fn x -> x.hash end)

    required_blocks = 
      for block <- current_map.chain,
        tx <- block.tx do
          if tx.txid in txids_to_find do
            block
          end
        end

    required_blocks = Enum.filter(required_blocks, &(&1 != nil))
  {:reply, required_blocks, current_map}
  end

  # Print state for debugging
  def handle_call({:get_state}, _from, current_map) do
    {:reply, current_map, current_map}
  end

end

# GenServer.cast(:"0441920A72D0B2F76C2D5DB39E034060C38B12B07F99DFCDD6063888312818DF15FC78834C3FE49EBB32B1E7DB540D08A3E07FA8C1D05D3C43A848BE8C8BFCCCA1", {:make_transaction,"0441920A72D0B2F76C2D5DB39E034060C38B12B07F99DFCDD6063888312818DF15FC78834C3FE49EBB32B1E7DB540D08A3E07FA8C1D05D3C43A848BE8C8BFCCCA1 048BC7CF874FDFBA95B765BC803D4003BBF4E98081F854D5975DF2E528A336D0726AD5E859A4D9562602C0E29D620834D6510071C7DB21A99ABFEF0F10B637A4C9 10.0"  , [ %{ :hash => "8A12EB159B4EE7320FE4FF04F6C1088D5A8F078A", :n => 0 }]})
# GenServer.cast(:"04EFEB65F418AB164360A5C51A6AA3A8B8B56150F21D6067EAA2C1E0F7FFAFCE472ECAEE94F4CFDF6E8EBCADB3A17C4D584EEFF0E076C9333383651EFEC0C29FFA",{:mine})
