defmodule HeexFormatter do
  @moduledoc """
  Documentation for `HeexFormatter`.
  """
  @behaviour Mix.Tasks.Format

  alias HeexFormatter.{Formatter, Tokenizer}

  @impl Mix.Tasks.Format
  def features(_opts) do
    [sigils: [:H], extensions: [".heex"]]
  end

  @impl Mix.Tasks.Format
  def format(contents, opts) do
    contents
    |> Tokenizer.tokenize()
    |> Formatter.format(opts)
  end
end
