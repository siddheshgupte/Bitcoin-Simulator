defmodule MerkleTreeNode do
    @moduledoc """
      This module implements a tree node abstraction.
    """
  
    defstruct [:value, :children]
  
    @type t :: %MerkleTreeNode{
      value: String.t,
      children: [MerkleTreeNode.t],
    }

    def flatten([]), do: []
    def flatten([h|t]), do: flatten(h) ++ flatten(t)
    def flatten(h), do: [h] 
    @doc """
    Builds a new binary merkle tree.
  """
 ## @spec new(blocks) :: root
  def build(blocks) do
    
    # getting transactions from 
    list_of_list = Enum.map(blocks, fn(block) ->
      transaction_list = block.out
      [] ++ temp = Enum.map(transaction_list, fn(transaction)->
        [] ++ transaction
      end)
    end)
    IO.inspect(list_of_list)

    flat_list = flatten(list_of_list)

    IO.inspect(flat_list)
    leaves = Enum.map(flat_list, fn(transaction) ->
      ip= transaction.sender <> transaction.receiver <> Float.to_string(transaction.amount)
      %MerkleTreeNode{
        value: :crypto.hash(:sha,ip) |> Base.encode16(),
        children: [],
      }
    end)
    build_tree(leaves)
  end

  defp build_tree([root]), do: root # Base case
  defp build_tree(nodes) do # Recursive case
    children_partitions = Enum.chunk(nodes, 2)
    parents = Enum.map(children_partitions, fn(partition) ->
      concatenated_values = partition
        |> Enum.map(&(&1.value))
        |> Enum.reduce("", fn(x, acc) -> acc <> x end)
      %MerkleTreeNode{
        value: :crypto.hash(:sha,concatenated_values) |> Base.encode16() ,
        children: partition
      }
    end)
    build_tree(parents)
  end
  end