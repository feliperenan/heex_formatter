defmodule Eef do
  @moduledoc """
  Documentation for `Eef`.
  """

  alias Phoenix.LiveView.HTMLTokenizer

  def format(text) do
    text
    |> HTMLTokenizer.tokenize("nofile", 0, [])
    |> Eef.Phases.NestElements.run()
    |> Eef.Render.as_string()
    |> IO.puts()
  end
end
