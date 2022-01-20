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
  def format(contents, _opts) do
    {nodes, _original} = tokenize(contents)

    nodes
    |> HeexFormatter.Phases.EnsureLineBreaks.run([])
    |> HeexFormatter.Phases.Render.run([])
  end

  @eex_expressions [:start_expr, :expr, :end_expr, :middle_expr]

  def tokenize(contents) do
    {:ok, eex_nodes} = EEx.Tokenizer.tokenize(contents, 0, 0, %{indentation: 0, trim: false})

    Enum.flat_map_reduce(eex_nodes, [], fn
      {:text, _line, _column, text}, acc ->
        string = List.to_string(text)
        {tokens, :text} = HTMLTokenizer.tokenize(string, "nofile", 0, [], [], :text)
        {Enum.reverse(tokens), [tokens | acc]}

      {type, line, column, opt, expr}, acc when type in @eex_expressions ->
        render = List.to_string(opt)
        meta = %{column: column + 1, line: line + 1}

        token =
          if render == "=" do
            tag = "<%= #{String.trim(to_string(expr))} %>"

            meta =
              if String.ends_with?(tag, "do %>") do
                Map.put(meta, :block?, true)
              else
                meta
              end

            {:eex_tag_open, tag, meta}
          else
            tag = "<% #{String.trim(to_string(expr))} %>"
            {:eex_tag_close, tag, meta}
          end

        {[token], [token | acc]}

      _node, acc ->
        {[], acc}
    end)
  end
end
