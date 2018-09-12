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

defmodule OMG.Watcher.Web.Controller.ChallengeTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.API.Fixtures

  alias OMG.API
  alias OMG.API.Block
  alias OMG.API.Crypto
  alias OMG.API.Utxo
  require Utxo
  alias OMG.Watcher.TestHelper
  alias OMG.Watcher.TransactionDB

  @moduletag :integration

  @eth Crypto.zero_address()

  describe "Controller.ChallengeTest" do
    @tag fixtures: [:phoenix_ecto_sandbox, :alice]
    test "utxo/:utxo_pos/challenge_data  endpoint returns proper response format", %{alice: alice} do
      TransactionDB.update_with(%Block{
        transactions: [
          API.TestHelper.create_recovered([{1, 1, 0, alice}], @eth, [{alice, 120}])
        ],
        number: 1
      })

      utxo_pos = Utxo.position(1, 1, 0) |> Utxo.Position.encode()

      %{
        "data" => %{
          "cutxopos" => _cutxopos,
          "eutxoindex" => _eutxoindex,
          "proof" => _proof,
          "sigs" => _sigs,
          "txbytes" => _txbytes
        },
        "result" => "success"
      } = TestHelper.rest_call(:get, "utxo/#{utxo_pos}/challenge_data")
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "utxo/:utxo_pos/challenge_data endpoint returns error for non existing utxo" do
      utxo_pos = Utxo.position(1, 1, 0) |> Utxo.Position.encode()

      %{
        "data" => %{
          "code" => "challenge:invalid",
          "description" => "The challenge of particular exit is invalid because provided utxo is not spent"
        },
        "result" => "error"
      } = TestHelper.rest_call(:get, "utxo/#{utxo_pos}/challenge_data")
    end
  end
end
