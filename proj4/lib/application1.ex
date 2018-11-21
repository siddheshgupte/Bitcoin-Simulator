defmodule Application1 do
  use Application

  def start(_type, num_of_nodes) do
    list_of_public_keys =
      1..num_of_nodes
      |> Enum.map(fn x ->
        identifier = :crypto.hash(:sha, Integer.to_string(x)) |> Base.encode16()
      end)

    genesis_block = start_blockchain(list_of_public_keys)

    # list_of_public keys has strings
    children =
      list_of_public_keys
      # |> Enum.to_list()
      |> Enum.map(fn str_identifier ->
        Supervisor.child_spec(
          {Proj4, [String.to_atom(str_identifier), genesis_block]},
          id: String.to_atom(str_identifier)
        )
      end)

    opts = [strategy: :one_for_one, name: Supervisor]
    {:ok, supervisor} = Supervisor.start_link(children, opts)

    # Get list of all children of the supervisor
    # lst_of_nodes has atoms
    lst_of_nodes =
      Supervisor.which_children(supervisor)
      |> IO.inspect()
      |> Enum.map(fn x -> elem(x, 0) end)

    # Make a fully connected network
    Enum.each(lst_of_nodes, fn x ->
      GenServer.cast(x, {:set_neighbours, List.delete(lst_of_nodes, x)})
    end)
  end

  # Make coin base with string identifier
  def make_coinbase(key) do
    transaction = %{
      :in => [
        %{
          # previous txid that we are claiming
          :hash => 000_000_000,
          # Index of transaction in the block
          :n => 0
        }
      ],
      :out => [
        %{
          :sender => "coinbase",
          :receiver => key,
          :amount => 25.0,
          :n => 0
        }
      ],
      :txid => :crypto.hash(:sha, "coinbase" <> key <> "25.0") |> Base.encode16()
    }
  end

  def start_blockchain(list_of_public_keys) do
    {nonce, hex_hash} =
      find_nonce_and_hash(1, "00_000_000_000_000", 1_542_078_479, "FirstBlock", 0)

    txs =
      list_of_public_keys
      |> Enum.map(fn x -> make_coinbase(x) end)

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
        :tx => txs,
        :mrkl_tree => [],
        :difficulty => 1
      }
    ]
  end

  # Return Nonce and hexadecimal hash
  def find_nonce_and_hash(index, prev_hash, time, mrkl_root, nonce) do
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
  def get_hash(index, prev_hash, time, mrkl_root, nonce) do
    ip =
      Integer.to_string(index) <>
        prev_hash <> Integer.to_string(time) <> mrkl_root <> Integer.to_string(nonce)

    hex_hash = :crypto.hash(:sha, ip) |> Base.encode16()
  end
end
