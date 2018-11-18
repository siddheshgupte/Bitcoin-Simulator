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

    # Get list of all children of the supervisor
    lst_of_nodes =
      Supervisor.which_children(supervisor)
      |> IO.inspect()
      |> Enum.map(fn x -> elem(x, 0) end)

    # Make a fully connected network
    Enum.each(lst_of_nodes, fn x ->
      GenServer.cast(x, {:set_neighbours, List.delete(lst_of_nodes, x)})
    end)
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
