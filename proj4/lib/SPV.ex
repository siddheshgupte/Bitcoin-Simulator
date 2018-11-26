defmodule SPV do
  @moduledoc """
      This module implements a SPV - i.e wallet.
      
   1. Get all required blocks from associated full node and cache them
   2. Check if inputs are valid
   3. Check Merkle root as well
   4. Make transaction (Make sure signature is done)
   5. Send to associated nodes {:add_transaction}

  """
  # use BloomFilter
  use GenServer, restart: :temporary
  import UtilityFn, only: :functions

  @type tx_in_t :: %{hash: String.t(), n: integer}
  @type tx_out_t :: %{sender: String.t(), receiver: String.t(), amount: float, n: integer}
  @type tx_t :: %{in: [tx_in_t], out: [tx_out_t], txid: String.t(), signature: String.t(), fee: float}
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
  def start_link([input_name, public_key, private_key, associated_full_node]) do
    GenServer.start_link(
      __MODULE__,
      %{
        :name => input_name,
        :public_key => public_key,
        :private_key => private_key,
        :associated_full_node => associated_full_node,
        :cached_blocks => [],
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

  @doc """
  Take input as a space separated string of the form "Receiver Amount"
  Transaction_ips is a list of transactions to use as input for this transaction
  transaction_ips is of the form [%{:hash => txid, :n => index of the transaction}, ...]

  Uses Bloom Filter to get required blocks from the full node and caches them
  """
  @spec handle_cast({:make_transaction, String.t(), [tx_in_t]}, map) :: {:noreply, map}
  def handle_cast({:make_transaction, ip_string, transaction_ips}, current_map) do
    # Split the input string
    # receiver 100.0
    [receiver, amount, fee] = String.split(ip_string)

    sender = current_map.public_key

    # 1. Get blocks from associated full node
    # 1. Check if inputs are valid
    # 2. Find the change address
    # 3. Add this change address to the transaction
    # 4. Find overall hash of the transaction (For all individual parts)
    # 5. Send to {:add_transaction}

    # Make a bloom filter using associated public addresses and send to associated full node
    bloom_filter_for_addresses = BloomFilter.new(10, 0.001)
    # Add addresses to bloom filter
    # Enum.each(current_map.public_keys, fn x -> BloomFilter.add(bloom_filter_for_addresses, current_map.public_key) end)
    bloom_filter_for_addresses = BloomFilter.add(bloom_filter_for_addresses, current_map.public_key)

    # TODO: check if we find the txid in cached blocks

    # Get blocks from associated full node
    required_blocks =
     GenServer.call(current_map.associated_full_node, {:get_required_blocks, bloom_filter_for_addresses, current_map.public_key})

    # Add to cached blocks
    {_, current_map} = 
      Map.get_and_update(current_map, :cached_blocks, fn x -> {x, required_blocks} end)

    txids_to_find =
      transaction_ips
      |> Enum.map(fn x -> x.hash end)

    required_blocks = Enum.filter(required_blocks, fn block ->
        for tx <- block.tx do
          tx.txid in txids_to_find
        end
    end)

    # Input to the are_inputs_valid_and_difference is a string
    amount_with_fee = (String.to_float(amount) + String.to_float(fee)) |> Float.to_string() 

    {are_inputs_valid?, balance} =
        UtilityFn.are_inputs_valid_and_difference(sender, amount_with_fee, required_blocks, transaction_ips)

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
      :fee => String.to_float(fee)
    }

    # # Add change address and set overall hash of transaction 
    # # Do this only if inputs are valid 
    transaction =
      if are_inputs_valid? do
        transaction
        # Add change address to transaction
        |> UtilityFn.add_change_address_to_transaction(balance, sender)
        # Set overall hash of the transaction
        |> UtilityFn.find_and_set_overall_hash_of_transaction()
        # Set signature
        # TODO: Change this to private key of the person doing the transaction
        |> UtilityFn.set_signature_of_transaction(current_map.private_key)
      end

    # # If this is a valid transaction, send to {:add_transaction} which will then gossip to other nodes
    if are_inputs_valid? do
      GenServer.cast(current_map.associated_full_node, {:add_transaction, transaction})
    end

    {:noreply, current_map}
  end

  
  # Print state for debugging
  def handle_cast({:print_state}, current_map) do
    IO.inspect(current_map)
    {:noreply, current_map}
  end
end


# GenServer.cast(:wallet_0441920A72D0B2F76C2D5DB39E034060C38B12B07F99DFCDD6063888312818DF15FC78834C3FE49EBB32B1E7DB540D08A3E07FA8C1D05D3C43A848BE8C8BFCCCA1, {:make_transaction," 048BC7CF874FDFBA95B765BC803D4003BBF4E98081F854D5975DF2E528A336D0726AD5E859A4D9562602C0E29D620834D6510071C7DB21A99ABFEF0F10B637A4C9 10.0 1.0"  , [ %{ :hash => "8A12EB159B4EE7320FE4FF04F6C1088D5A8F078A", :n => 0 }]})
# GenServer.cast(:"04EFEB65F418AB164360A5C51A6AA3A8B8B56150F21D6067EAA2C1E0F7FFAFCE472ECAEE94F4CFDF6E8EBCADB3A17C4D584EEFF0E076C9333383651EFEC0C29FFA",{:mine})
