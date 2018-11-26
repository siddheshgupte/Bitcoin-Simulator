defmodule UtilityFn do
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

  # Returns a tuple {are_inputs_valid?, balance}
  # balance is (amounts in referred transactions - amount to send)
  # transaction_ip is of the form [%{:hash => txid, :n => index of the transaction}]
  @spec are_inputs_valid_and_difference(String.t(), String.t(), list, [tx_in_t]) ::
          {boolean, float}
  def are_inputs_valid_and_difference(sender, amount, chain, transaction_ips) do
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
  def find_nonce_and_hash(index, prev_hash, time, mrkl_root, nonce) do
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
  def get_hash(index, prev_hash, time, mrkl_root, nonce) do
    ip =
      Integer.to_string(index) <>
        prev_hash <> Integer.to_string(time) <> mrkl_root <> Integer.to_string(nonce)

    :crypto.hash(:sha, ip) |> Base.encode16()
  end

  @spec verify_block_hash(block_t) :: boolean
  def verify_block_hash(block) do
    # Check if incoming block is valid
    get_hash(block.index, block.prev_hash, block.time, block.mrkl_root, block.nonce) == block.hash
  end

  # Verify if blockchain is valid
  @spec verify_blockchain([block_t]) :: boolean
  def verify_blockchain(chain) do
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

    length(invalid_hash_blocks) == 0 and length(invalid_chain) == 0
  end

  @spec add_coinbase_transaction(atom, [tx_t]) :: [tx_t]
  def add_coinbase_transaction(public_key, curr_tx) do
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
  def get_list_highest_priority_uncommitted_transactions(lst_uncommitted_transactions) do
    # TODO: Return transactions according to the fees here
    lst_uncommitted_transactions
  end

  def get_mrkl_tree_and_root(lst_tx) do
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
  def get_hash_for_transaction(transaction) do
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
  def check_if_transaction_valid(transaction) do
    txid_calculated = get_hash_for_transaction(transaction)
    txid_calculated == transaction.txid
  end

  @spec is_not_double_spend?(tx_t, [tx_t], [block_t]) :: boolean
  def is_not_double_spend?(transaction, uncommitted_transactions, chain) do
    # 1. Check in uncommitted transactions if the input is equal to the inputs given here
    # 2. Check all blocks' transactions inputs to check if input is equal to the inputs given here 

    results =
      for uc_tx <- uncommitted_transactions,
          input <- uc_tx.in do
        input in transaction.in
      end

    uncommitted_not_double_spent = Enum.filter(results, fn x -> x != false end) |> length() == 0

    chain_not_double_spent =
      if uncommitted_not_double_spent do
        results =
          for block <- chain,
              tx <- block.tx,
              input <- tx.in do
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
  def check_if_all_transactions_valid(block) do
    # For each transaction in block call check_if_transaction_valid()

    invalid_transactions =
      block.tx
      # Check which elements return false for check_if_transaction_valid 
      |> Enum.filter(fn tx -> not check_if_transaction_valid(tx) end)

    # Return true for now because this is being used in mine method
    length(invalid_transactions) == 0
  end

  def check_signature(transaction, public_key) do
    {_, signature} = transaction.signature |> Base.decode16()
    {_, public_key} = public_key |> Atom.to_string() |> Base.decode16()

    :crypto.verify(:ecdsa, :sha256, transaction.txid, signature, [public_key, :secp256k1])
  end

  @spec remove_transactions_from_uncommitted_transactions([tx_t], map) :: map
  def remove_transactions_from_uncommitted_transactions(tx_to_remove, current_map) do
    new_uncommitted =
      Enum.filter(current_map.uncommitted_transactions, fn x -> x not in tx_to_remove end)

    {_, map_to_return} =
      Map.get_and_update(current_map, :uncommitted_transactions, fn x -> {x, new_uncommitted} end)

    map_to_return
  end

  # Add change address to the transaction output with given balance
  # Assign index to the change address
  @spec add_change_address_to_transaction(map, float, String.t()) :: tx_t
  def add_change_address_to_transaction(transaction, balance, sender) do
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
  def find_and_set_overall_hash_of_transaction(transaction) do
    txid_to_set = get_hash_for_transaction(transaction)

    {_, transaction} = Map.get_and_update(transaction, :txid, fn x -> {x, txid_to_set} end)

    # Return updated map with the new hash
    transaction
  end

  # Check if inputs of the transaction are valid
  # This checks it for all the transactions in the transaction.out
  # i.e calls are_inputs_valid_and_difference() for all transactions in transaction.out
  @spec inputs_of_transaction_valid?(tx_t, map) :: boolean
  def inputs_of_transaction_valid?(transaction, current_map) do
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

  @spec set_signature_of_transaction(tx_t, String.t()) :: tx_t
  def set_signature_of_transaction(transaction, private_key) do
    signature =
      :crypto.sign(:ecdsa, :sha256, transaction.txid, [private_key, :secp256k1])
      |> Base.encode16()

    {_, transaction} = Map.get_and_update(transaction, :signature, fn x -> {x, signature} end)
    transaction
  end

  def get_sender_from_transaction(transaction) do
   senders = 
    for op <- transaction.out do
        if op.sender != "coinbase" do
            op.sender
        end
    end
    Enum.at(senders, 0)
  end
end
