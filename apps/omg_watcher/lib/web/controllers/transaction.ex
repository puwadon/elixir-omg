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

defmodule OMG.Watcher.Web.Controller.Transaction do
  @moduledoc """
  Operations related to transaction.
  """

  use OMG.Watcher.Web, :controller
  use PhoenixSwagger

  alias OMG.API.State.Transaction.Signed
  alias OMG.Watcher.TransactionDB
  alias OMG.Watcher.Web.View

  import OMG.Watcher.Web.ErrorHandler

  @doc """
  Retrieves a specific transaction by id.
  """
  def get_transaction(conn, %{"id" => id}) do
    id
    |> Base.decode16!()
    |> TransactionDB.get()
    |> respond(conn)
  end

  defp respond(%TransactionDB{} = transaction, conn) do
    render(conn, View.Transaction, :transaction, transaction: transaction)
  end

  defp respond(nil, conn) do
    handle_error(conn, :transaction_not_found)
  end

  def swagger_definitions do
    %{
      Transaction:
        swagger_schema do
          title("Transaction")

          properties do
            txid(:string, "Transaction id", required: true)
            blknum1(:integer, "Childchain block number of the first input utxo", required: true)
            txindex1(:integer, "Transaction index of the first input utxo", required: true)
            oindex1(:integer, "Output index of the first input utxo", required: true)
            blknum2(:integer, "Childchain block number of the second input utxo", required: true)
            txindex2(:integer, "Transaction index of the second input utxo", required: true)
            oindex2(:integer, "Output index of the second input utxo", required: true)
            cur12(:string, "Currency of the transaction", required: true)
            newowner1(:string, "Address of the owner of the first output utxo", required: true)
            amount1(:integer, "Amount of currency in the first output utxo", required: true)
            newowner2(:string, "Address of the owner of the second output utxo", required: true)
            amount2(:integer, "Amount of currency in the second output utxo", required: true)
            txblknum(:integer, "Number of block that the transaction is included in", required: true)
            txindex(:integer, "Transaction index", required: true)
            sig1(:string, "Signature of owner of the first input utxo", required: true)
            sig2(:string, "Signature of owner of the second input utxo", required: true)
            spender1(:string, "Address of owner of the first input utxo", required: true)
            spender2(:string, "Address of owner of the second input utxo", required: true)
          end

          example(%{
            txid: "5DF13A6BF96DBCF6E66D8BABD6B55BD40D64D4320C3B115364C6588FC18C2A21",
            blknum1: 1000,
            txindex1: 2,
            oindex1: 0,
            blknum2: 2000,
            txindex2: 0,
            oindex2: 1,
            cur12: "0000000000000000000000000000000000000000",
            newowner1: "B3256026863EB6AE5B06FA396AB09069784EA8EA",
            amount1: 1,
            newowner2: "0000000000000000000000000000000000000000",
            amount2: 2,
            txblknum: 3000,
            txindex: 1,
            sig1:
              "F3050F1CC506480EFFBD78CB2FB21074AD3545564520F1E58F8F7BA1E37EF35450EB406A4173524CA0A6C4DE4D7EF7E814E161795EB8D852033E60F3539E61F71B",
            sig2:
              "0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
            spender1: "92EAD0DB732692FF887268DA965C311AC2C9005B",
            spender2: "92EAD0DB732692FF887268DA965C311AC2C9005B"
          })
        end
    }
  end

  swagger_path :get_transaction do
    get("/transaction")
    summary("Gets a transaction with the given id")

    parameters do
      id(:path, :integer, "Id of the transaction", required: true)
    end

    response(200, "OK", Schema.ref(:Transaction))
  end
end
