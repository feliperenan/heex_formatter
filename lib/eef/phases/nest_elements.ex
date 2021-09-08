defmodule Eef.Phases.NestElements do
  @moduledoc false

  def run(nodes) do
    combine(nodes)
  end

  def combine(nodes, search \\ nil, acc \\ [])

  def combine([], _search, []) do
    []
  end

  def combine([], _search, acc) do
    acc |> Enum.reverse()
  end

  def combine([{:tag_open, name, attrs, meta} | rest], search, acc) do
    if has_matching_close?(rest, name) do
      case combine(rest, name) do
        [] ->
          combine([], nil, [{:element, name, attrs, [], meta} | acc])

        children when is_list(children) ->
          combine([], nil, [
            {:element, name, attrs, children, meta} | acc
          ])

        {children, remaining} ->
          combine(remaining, nil, [
            {:element, name, attrs, children, meta} | acc
          ])
      end
    else
      # Inbalanced or functional component
      combine(rest, search, [{:element, name, attrs, [], meta} | acc])
    end
  end

  def combine([{:tag_close, search, _meta} | rest], search, acc) do
    {Enum.reverse(acc), rest}
  end

  def combine([node | rest], search, acc) do
    combine(rest, search, [node | acc])
  end

  defp has_matching_close?(nodes, search) do
    Enum.any?(
      nodes,
      fn
        {:tag_close, ^search, _meta} -> true
        _ -> false
      end
    )
  end
end
