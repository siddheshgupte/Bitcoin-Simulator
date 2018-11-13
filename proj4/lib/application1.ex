defmodule Application1 do
  use Application

  def start(_type, num_of_nodes) do
    genesis_block = start_blockchain()

    children =
      1..num_of_nodes
      |> Enum.to_list()
      |> Enum.map(fn x ->
        # Change later if slow
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
    [
      %{
        :index => 1,
        :nonce => 2,
        # :coinbase => [],
        # :difficulty => ?,
        :tx => "abc",
        :prev_hash => "00_000_000_000_000",
        :time_stamp => 1_542_078_479,
        :difficulty => 0,
        :hash => "C16BE0090E95E0FDA0BD22F95E9D5B4B9B1331EE"
      }
    ]
  end

  def find_nonce_and_hash(index, tx, prev_hash, time_stamp, nonce) do
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
