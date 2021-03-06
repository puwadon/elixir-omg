# Copyright 2018 OmiseGO Pte Ltd
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

defmodule OMG.Eth do
  @moduledoc """
  Library for common code of the adapter/port to contracts deployed on Ethereum.
  NOTE: The library code is not intended to be used outside of `Eth`: use `Eth.RootChain` and `Eth.Token` as main
  entrypoints to the contract-interaction functionality.

  NOTE: this `OMG.Eth`/`omg_eth` wrapper is intended to be as thin and stupid as possible, only offering a convenient,
  consistent API to the Ethereum JSONRPC client and contracts.

  Also other non-contract querries to the Ethereum client.

  Notes on encoding: All APIs of `OMG.Eth` and the submodules with contract APIs always use raw, decoded binaries
  for binaries - never use hex encoded binaries. Such binaries may be passed as is onto `ABI` related functions,
  however they must be encoded/decoded when entering/leaving the `Ethereumex` realm
  """

  import OMG.Eth.Encoding
  alias OMG.Eth.WaitFor

  @type address :: <<_::160>>

  def get_ethereum_height do
    case Ethereumex.HttpClient.eth_block_number() do
      {:ok, "0x" <> height_hex} ->
        {height, ""} = Integer.parse(height_hex, 16)
        {:ok, height}

      other ->
        other
    end
  end

  def call_contract(contract, signature, args, return_types) do
    data = signature |> ABI.encode(args)

    with {:ok, return} <- Ethereumex.HttpClient.eth_call(%{to: to_hex(contract), data: to_hex(data)}),
         do: decode_answer(return, return_types)
  end

  defp decode_answer(enc_return, return_types) do
    enc_return
    |> from_hex()
    |> ABI.TypeDecoder.decode_raw(return_types)
    |> case do
      [single_return] -> {:ok, single_return}
      other when is_list(other) -> {:ok, List.to_tuple(other)}
    end
  end

  @spec contract_transact(address, address, binary, [any], keyword) :: {:ok, binary} | {:error, any}
  def contract_transact(from, to, signature, args, opts \\ []) do
    data = encode_tx_data(signature, args)

    txmap =
      %{from: to_hex(from), to: to_hex(to), data: data}
      |> Map.merge(Map.new(opts))
      |> encode_all_integer_opts()

    with {:ok, txhash} <- Ethereumex.HttpClient.eth_send_transaction(txmap),
         do: {:ok, from_hex(txhash)}
  end

  defp encode_all_integer_opts(opts) do
    opts
    |> Enum.filter(fn {_k, v} -> is_integer(v) end)
    |> Enum.into(opts, fn {k, v} -> {k, to_hex(v)} end)
  end

  def get_bytecode!(path_project_root, contract_name) do
    %{"evm" => %{"bytecode" => %{"object" => bytecode}}} =
      path_project_root
      |> read_contracts_json!(contract_name)
      |> Poison.decode!()

    "0x" <> bytecode
  end

  defp encode_tx_data(signature, args) do
    signature
    |> ABI.encode(args)
    |> to_hex()
  end

  defp encode_constructor_params(args, types) do
    args
    |> ABI.TypeEncoder.encode_raw(types)
    # NOTE: we're not using `to_hex` because the `0x` will be appended to the bytecode already
    |> Base.encode16(case: :lower)
  end

  def deploy_contract(addr, bytecode, types, args, opts) do
    enc_args = encode_constructor_params(types, args)

    txmap =
      %{from: to_hex(addr), data: bytecode <> enc_args}
      |> Map.merge(Map.new(opts))
      |> encode_all_integer_opts()

    {:ok, txhash} = Ethereumex.HttpClient.eth_send_transaction(txmap)

    {:ok, %{"contractAddress" => contract_address, "status" => "0x1"}} =
      txhash
      |> from_hex()
      |> WaitFor.eth_receipt()

    {:ok, from_hex(txhash), from_hex(contract_address)}
  end

  defp read_contracts_json!(path_project_root, contract_name) do
    path = "contracts/build/#{contract_name}.json"

    case File.read(Path.join(path_project_root, path)) do
      {:ok, contract_json} ->
        contract_json

      {:error, reason} ->
        raise(
          RuntimeError,
          "Can't read #{path} because #{inspect(reason)}, try running mix deps.compile plasma_contracts"
        )
    end
  end

  defp event_topic_for_signature(signature) do
    signature |> ExthCrypto.Hash.hash(ExthCrypto.Hash.kec()) |> to_hex()
  end

  defp filter_not_removed(logs) do
    logs |> Enum.filter(&(not Map.get(&1, "removed", true)))
  end

  def get_ethereum_events(block_from, block_to, signature, contract) do
    topic = event_topic_for_signature(signature)

    try do
      {:ok, logs} =
        Ethereumex.HttpClient.eth_get_logs(%{
          fromBlock: to_hex(block_from),
          toBlock: to_hex(block_to),
          address: to_hex(contract),
          topics: ["#{topic}"]
        })

      {:ok, filter_not_removed(logs)}
    catch
      _ -> {:error, :failed_to_get_ethereum_events}
    end
  end

  def parse_event(%{"data" => data}, {signature, keys}) do
    decoded_values =
      data
      |> from_hex()
      |> ABI.TypeDecoder.decode(ABI.FunctionSelector.decode(signature))

    Enum.zip(keys, decoded_values)
    |> Map.new()
  end

  def parse_events_with_indexed_fields(
        %{"data" => data, "topics" => [_event_sig | indexed_data]},
        {non_indexed_keys, non_indexed_key_types},
        {indexed_keys, indexed_keys_types}
      ) do
    decoded_non_indexed_fields =
      data
      |> from_hex()
      |> ABI.TypeDecoder.decode_raw(non_indexed_key_types)

    non_indexed_fields =
      Enum.zip(non_indexed_keys, decoded_non_indexed_fields)
      |> Map.new()

    decoded_indexed_fields =
      for {encoded, type_sig} <- Enum.zip(indexed_data, indexed_keys_types) do
        [decoded] =
          encoded
          |> from_hex()
          |> ABI.TypeDecoder.decode_raw([type_sig])

        decoded
      end

    indexed_fields =
      Enum.zip(indexed_keys, decoded_indexed_fields)
      |> Map.new()

    Map.merge(non_indexed_fields, indexed_fields)
  end
end
