defmodule Application1 do
  use Application
  @moduledoc """
  Driver module for initializing the simulation
  """

  def start(_type, num_of_nodes) do
    list_of_private_keys =
      1..num_of_nodes
      |> Enum.map(fn x ->
        :crypto.hash(:sha, Integer.to_string(x)) |> Base.encode16()
      end)

    list_of_public_keys =
      list_of_private_keys
      |> Enum.map(fn x ->
        {public_key, _} = :crypto.generate_key(:ecdh, :secp256k1, x)
        public_key |> Base.encode16()
      end)

    genesis_block = start_blockchain(list_of_public_keys, list_of_private_keys)

    # list_of_public keys has strings
    children =
      Enum.zip(list_of_public_keys, list_of_private_keys)
      |> Enum.map(fn ele ->
        {public_key, private_key} = ele

        Supervisor.child_spec(
          {FullNode, [String.to_atom(public_key), private_key, genesis_block]},
          id: String.to_atom(public_key)
        )
      end)

    wallets =
      Enum.zip(list_of_public_keys, list_of_private_keys)
      |> Enum.map(fn ele ->
        {public_key, private_key} = ele

        Supervisor.child_spec(
          {SPV,
           [
             String.to_atom("wallet_#{public_key}"),
             public_key,
             private_key,
             String.to_atom(public_key)
           ]},
          id: String.to_atom("wallet_#{public_key}")
        )
      end)

    children = children

    opts = [strategy: :one_for_one, name: Supervisor]
    {:ok, supervisor} = Supervisor.start_link(children, opts)

    # Get list of all children of the supervisor
    # lst_of_nodes has atoms
    lst_of_nodes =
      Supervisor.which_children(supervisor)
      |> Enum.map(fn x -> elem(x, 0) end)

    # Make a fully connected network
    Enum.each(lst_of_nodes, fn x ->
      GenServer.cast(x, {:set_neighbours, List.delete(lst_of_nodes, x)})
    end)

    Enum.each(wallets, fn x -> Supervisor.start_child(supervisor, x) end)
    lst_of_nodes
  end


  # Make coin base with string identifier
  @spec make_coinbase({String.t(), String.t()}) :: map
  def make_coinbase({public_key, private_key}) do
    %{
      :in => [
        %{
          # previous txid that we are claiming
          :hash => "000000000",
          # Index of transaction in the block
          :n => 0
        }
      ],
      :out => [
        %{
          :sender => "coinbase",
          :receiver => public_key,
          :amount => 25.0,
          :n => 0
        }
      ],
      :txid => :crypto.hash(:sha, "coinbase" <> public_key <> "25.0") |> Base.encode16(),
      :signature => "Placeholder",
      :fee => 0.0,
    }
    |> set_signature_of_transaction(private_key)
  end

  def start_blockchain(list_of_public_keys, list_of_private_keys) do
    {nonce, hex_hash} =
      find_nonce_and_hash(1, "00_000_000_000_000", 1_542_078_479, "FirstBlock", 0)

    txs =
      Enum.zip(list_of_public_keys, list_of_private_keys)
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

  defp set_signature_of_transaction(transaction, private_key) do
    signature =
      :crypto.sign(:ecdsa, :sha256, transaction.txid, [private_key, :secp256k1])
      |> Base.encode16()

    {_, transaction} = Map.get_and_update(transaction, :signature, fn x -> {x, signature} end)
    transaction
  end
end
