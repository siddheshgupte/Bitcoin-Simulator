defmodule Application1 do
  use Application

  def start(_type, num_of_nodes) do
    genesis_block = start_blockchain()

    children =
      1..num_of_nodes
      |> Enum.to_list()
      |> Enum.map(fn x ->
        identifier = :crypto.hash(:sha, Integer.to_string(x)) |> Base.encode16()

        Supervisor.child_spec(
          {Proj4, [String.to_atom("#{identifier}"), genesis_block]},
          id: String.to_atom("#{identifier}")
        )
      end)

    opts = [strategy: :one_for_one, name: Supervisor]
    {:ok, supervisor} = Supervisor.start_link(children, opts)

    Supervisor.which_children(supervisor)
  end

  def start_blockchain() do

    {nonce, hex_hash} =
      find_nonce_and_hash(1, "00_000_000_000_000", 1_542_078_479, "FirstBlock", 0)
    
    [
      %{
        # Header 
        :index => 1,
        :hash => hex_hash,
        :prev_hash => "00_000_000_000_000",
        :time => 1_542_078_479,
        :nonce => nonce,

        # Transaction Data
        :mrkl_root => "FirstBlock",
        :n_tx => 0,
        :tx => [],
        :mrkl_tree => [],
        :difficulty => 1,
      }
    ]

  end

  # Return Nonce and hexadecimal hash
  def find_nonce_and_hash(index, prev_hash, time, mrkl_root, nonce) do
    
    hex_hash =
      get_hash(index, prev_hash, time, mrkl_root, nonce)

    {nonce, hex_hash} =
      # Check if first digit is zero 
      if Enum.at(Integer.digits(hex_hash), 0) == 0 do
        {nonce, hex_hash}
      else
        find_nonce_and_hash(index, prev_hash, time, mrkl_root, nonce + 1)
      end
  end

  # Return hexadecimal hash
  def get_hash(index, prev_hash, time, mrkl_root, nonce) do
    ip =
      Integer.to_string(index) <>
      prev_hash <> Integer.to_string(time) <> mrkl_root <> Integer.to_string(nonce) 

    hex_hash = :crypto.hash(:sha, ip) |> Base.encode16()
  end


  # def test_add_transaction(transaction, chain) when is_binary(transaction) do
  #   prev_block = Enum.at(chain, 0)

  #   # Initializations
  #   curr_index = prev_block.index + 1
  #   curr_tx = transaction
  #   curr_prev_hash = prev_block.hash
  #   {curr_nonce, curr_hash} = find_nonce(curr_index, curr_tx, curr_prev_hash, 0)

  #   # Make block
  #   curr_block = 
  #   %{
  #     :index => curr_index,
  #     :nonce => curr_nonce,
  #     # :coinbase => [],
  #     :tx => curr_tx,
  #     :prev_hash => curr_prev_hash,
  #     :hash => curr_hash,
  #   }

  #   # Add block to blockchain
  #   chain = [curr_block | chain]
  # end
end
