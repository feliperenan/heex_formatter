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
    {text, eex_tokenizer_nodes} = extract_eex_text(contents)
    {html_nodes, :text} = HTMLTokenizer.tokenize(text, "nofile", 0, [], [], :text)

    html_nodes
    |> join_nodes(eex_tokenizer_nodes)
    |> HeexFormatter.Phases.EnsureLineBreaks.run([])
    |> HeexFormatter.Phases.Render.run([])
  end

  def join_nodes(html_nodes, eex_tokenizer_nodes) do
    new_nodes =
      eex_tokenizer_nodes
      |> Enum.reduce([], fn
        {type, line, column, opt, expr}, acc
        when type in [:start_expr, :expr, :end_expr, :middle_expr] ->
          render = List.to_string(opt)
          meta = %{column: column + 1, line: line + 1}

          if render == "=" do
            tag = "<%= #{String.trim(to_string(expr))} %>"

            meta =
              if String.ends_with?(tag, "do %>") do
                Map.put(meta, :block?, true)
              else
                meta
              end

            [{:eex_tag_open, tag, meta} | acc]
          else
            tag = "<% #{String.trim(to_string(expr))} %>"
            [{:eex_tag_close, tag, meta} | acc]
          end

        _expr, acc ->
          acc
      end)

    (html_nodes ++ new_nodes)
    |> Enum.reverse()
    |> Enum.reject(&(&1 == {:text, "\n", %{}}))
    |> Enum.sort_by(fn
      {_, _, _, %{line: line, column: column}} ->
        {line, column}

      {_, _, %{column_end: column_end, line_end: line_end}} ->
        {line_end, column_end}

      {_, _, %{column: column, line: line}} ->
        {line, column}
    end)
  end

  defp extract_eex_text(contents) do
    {:ok, nodes} = EEx.Tokenizer.tokenize(contents, 0, 0, %{indentation: 0, trim: false})

    text =
      Enum.reduce(nodes, "", fn
        {:text, _line, _col, text}, acc ->
          acc <> List.to_string(text)

        _node, acc ->
          acc
      end)

    {text, nodes}
  end
end
