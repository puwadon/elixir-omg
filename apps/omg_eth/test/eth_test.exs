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

defmodule OMG.EthTest do
  @moduledoc """
  Thin smoke test of the Ethereum port/adapter.

  Note the excluded moduletag, this test requires an explicit `--include`
  """
  # TODO: if proves to be brittle and we cover that functionality in other integration test then consider removing
  #       UPDATE: up for revamp and reduction in OMG-225

  alias OMG.API.Block
  alias OMG.API.Crypto
  alias OMG.API.State.Transaction
  alias OMG.API.Utxo
  alias OMG.Eth, as: Eth
  alias OMG.Eth.WaitFor, as: WaitFor
  alias OMG.Watcher.DB.TransactionDB
  alias OMG.Watcher.DB.TxOutputDB

  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.API.Fixtures

  require Utxo

  @timeout 20_000

  @eth Crypto.zero_address()

  @moduletag :wrappers

  defp generate_transaction(nonce) do
    hash = :crypto.hash(:sha256, to_charlist(nonce))

    %OMG.API.BlockQueue.Core.BlockSubmission{
      num: nonce,
      hash: hash,
      gas_price: 20_000_000_000,
      nonce: nonce
    }
  end

  defp deposit(contract) do
    {:ok, txhash} = Eth.RootChain.deposit(1, contract.authority_addr, contract.contract_addr)
    {:ok, %{"status" => "0x1"}} = WaitFor.eth_receipt(txhash, @timeout)
  end

  defp start_exit(utxo_position, txbytes, proof, sigs, gas_price, from, contract) do
    {:ok, txhash} = Eth.RootChain.start_exit(utxo_position, txbytes, proof, sigs, gas_price, from, contract)

    {:ok, _} = WaitFor.eth_receipt(txhash, @timeout)
  end

  defp exit_deposit(contract) do
    deposit_pos = Utxo.position(1, 0, 0) |> Utxo.Position.encode()

    data = "startDepositExit(uint256,address,uint256)" |> ABI.encode([deposit_pos, @eth, 1]) |> Base.encode16()

    {:ok, transaction_hash} =
      Ethereumex.HttpClient.eth_send_transaction(%{
        from: contract.authority_addr,
        to: contract.contract_addr,
        data: "0x#{data}",
        gas: "0x2D0900"
      })

    {:ok, _} = WaitFor.eth_receipt(transaction_hash, @timeout)
  end

  defp add_blocks(range, contract) do
    for nonce <- range do
      tx = generate_transaction(nonce)

      {:ok, txhash} =
        Eth.RootChain.submit_block(tx.hash, tx.nonce, tx.gas_price, contract.authority_addr, contract.contract_addr)

      {:ok, _receipt} = WaitFor.eth_receipt(txhash, @timeout)
      {:ok, next_num} = Eth.RootChain.get_current_child_block(contract.contract_addr)
      assert next_num == (nonce + 1) * 1000
    end
  end

  @tag fixtures: [:contract, :alice, :bob]
  test "start_exit", %{contract: contract, alice: alice, bob: bob} do
    {:ok, bob_address} = Eth.DevHelpers.import_unlock_fund(bob)

    raw_tx = %Transaction{
      amount1: 8,
      amount2: 3,
      blknum1: 1,
      blknum2: 0,
      newowner1: bob.addr,
      newowner2: alice.addr,
      cur12: @eth,
      oindex1: 0,
      oindex2: 0,
      txindex1: 0,
      txindex2: 0
    }

    signed_tx = Transaction.sign(raw_tx, bob.priv, alice.priv)

    {:ok,
     %Transaction.Recovered{signed_tx: %Transaction.Signed{signed_tx_bytes: txbytes}, signed_tx_hash: txhash} =
       recovered_tx} = Transaction.Recovered.recover_from(signed_tx)

    block = Block.hashed_txs_at([recovered_tx], 1000)

    {:ok, txhash} =
      Eth.RootChain.submit_block(block.hash, 1, 20_000_000_000, contract.authority_addr, contract.contract_addr)

    {:ok, _} = WaitFor.eth_receipt(txhash, @timeout)

    txs = [%TransactionDB{blknum: 1000, txindex: 0, txhash: txhash, txbytes: txbytes}]

    {:ok, child_blknum} = Eth.RootChain.get_mined_child_block(contract.contract_addr)

    # TODO re: brittleness and dirtyness of this - test requires TxOutputDB calls,
    # duplicates our integrations tests - another reason to drop or redesign eth_test.exs sometime
    %{utxo_pos: utxo_pos, txbytes: txbytes, proof: proof, sigs: sigs} =
      TxOutputDB.compose_utxo_exit(txs, Utxo.position(child_blknum, 0, 0))

    {:ok, _} = start_exit(utxo_pos, txbytes, proof, sigs, 1, bob_address, contract.contract_addr)

    {:ok, height} = Eth.get_ethereum_height()

    utxo_pos = Utxo.position(1000, 0, 0) |> Utxo.Position.encode()

    assert {:ok, [%{amount: 8, owner: bob.addr, utxo_pos: utxo_pos, token: @eth}]} ==
             Eth.RootChain.get_exits(1, height, contract.contract_addr)
  end

  @tag fixtures: [:contract]
  test "child block increment after add block", %{contract: contract} do
    add_blocks(1..4, contract)
    # current child block is a num of the next operator block:
    {:ok, 5000} = Eth.RootChain.get_current_child_block(contract.contract_addr)
  end

  @tag fixtures: [:geth]
  test "get_ethereum_height return integer" do
    {:ok, number} = Eth.get_ethereum_height()
    assert is_integer(number)
  end

  @tag fixtures: [:contract]
  test "get child chain", %{contract: contract} do
    add_blocks(1..8, contract)
    block = generate_transaction(4)
    {:ok, 8000} = Eth.RootChain.get_mined_child_block(contract.contract_addr)
    {:ok, {child_chain_hash, _child_chain_time}} = Eth.RootChain.get_child_chain(4000, contract.contract_addr)
    assert block.hash == child_chain_hash
  end

  @tag fixtures: [:contract]
  test "gets deposits from a range of blocks", %{contract: contract} do
    deposit(contract)
    {:ok, height} = Eth.get_ethereum_height()

    assert {:ok, [%{amount: 1, blknum: 1, owner: Crypto.decode_address!(contract.authority_addr), currency: @eth}]} ==
             Eth.RootChain.get_deposits(1, height, contract.contract_addr)
  end

  @tag fixtures: [:contract]
  test "get contract deployment height", %{contract: contract} do
    {:ok, number} = Eth.RootChain.get_root_deployment_height(contract.txhash_contract, contract.contract_addr)
    assert is_integer(number)
  end

  @tag fixtures: [:contract]
  test "get exits from a range of blocks", %{contract: contract} do
    deposit(contract)
    exit_deposit(contract)
    {:ok, height} = Eth.get_ethereum_height()

    utxo_pos = Utxo.position(1, 0, 0) |> Utxo.Position.encode()

    assert(
      {:ok, [%{owner: Crypto.decode_address!(contract.authority_addr), utxo_pos: utxo_pos, token: @eth, amount: 1}]} ==
        Eth.RootChain.get_exits(1, height, contract.contract_addr)
    )
  end

  @tag fixtures: [:contract]
  test "get mined block number", %{contract: contract} do
    {:ok, number} = Eth.RootChain.get_mined_child_block(contract.contract_addr)
    assert is_integer(number)
  end

  @tag fixtures: [:contract]
  test "get authority for deployed contract", %{contract: contract} do
    {:ok, addr} = Eth.RootChain.authority(contract.contract_addr)
    {:ok, encoded_addr} = Crypto.encode_address(addr)
    assert contract.authority_addr == encoded_addr
  end
end
