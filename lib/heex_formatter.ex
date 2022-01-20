defmodule HeexFormatter do
  @moduledoc """
  Documentation for `HeexFormatter`.
  """
  @behaviour Mix.Tasks.Format

  alias Phoenix.LiveView.HTMLTokenizer

  @impl Mix.Tasks.Format
  def features(_opts) do
    [sigils: [:H], extensions: [".heex"]]
  end

  @impl Mix.Tasks.Format
  def format(contents, opts) do
    contents
    |> HeexFormatter.Phases.Tokenizer.run(opts)
    |> HeexFormatter.Phases.EnsureLineBreaks.run(opts)
    |> HeexFormatter.Phases.Render.run(opts)
  end
end
