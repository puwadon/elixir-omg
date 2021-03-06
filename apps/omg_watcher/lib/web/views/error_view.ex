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

defmodule OMG.Watcher.Web.View.ErrorView do
  use OMG.Watcher.Web, :view

  alias OMG.Watcher.Web.Serializer

  @doc """
  Supports internal server error thrown by Phoenix.
  """
  def render("500.json", %{reason: %{message: message}}) do
    render_error("server:internal_server_error", message)
  end

  @doc """
  Supports bad request error thrown by Phoenix.
  """
  def render("400.json", %{reason: %{message: message}}) do
    render_error("client:invalid_parameter", message)
  end

  @doc """
  Renders error when no render clause matches or no template is found.
  """
  def template_not_found(_template, _assigns) do
    render_error(
      "server:internal_server_error",
      "Something went wrong on the server or template cannot be found."
    )
  end

  defp render_error(code, message) do
    code
    |> Serializer.Error.serialize(message)
    |> Serializer.Response.serialize(:error)
  end
end
