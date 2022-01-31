defmodule HeexFormatter.HtmlTree do
  @moduledoc false

  @doc """
  Build an HTML Tree givens tokens from `Tokenizer.tokenize/1`
  """
  def build(tokens) do
    to_tree(tokens, [], [])
  end

  def to_tree([], buffer, [:tag_close | tree]), do: to_tree([], buffer, tree)
  def to_tree([], _buffer, tree), do: Enum.reverse(tree)

  def to_tree([{:tag_open, _n, _a, _m} = token | tokens], [], []) do
    to_tree(tokens, [], [build_tag_block(token)])
  end

  def to_tree([{:tag_open, _n, _a, _m} = token | tokens], buffer, []) do
    to_tree(tokens, [], [build_tag_block(token) | buffer])
  end

  def to_tree([{:tag_open, _n, _a, _m} = token | tokens], buffer, [:tag_close | rest]) do
    to_tree(tokens, buffer, [build_tag_block(token) | rest])
  end

  def to_tree([{:tag_open, _n, _a, _m} = token | tokens], buffer, [current | rest] = tree) do
    tag_block = build_tag_block(token)

    if tag_block?(current) do
      to_tree(tokens, [tag_block | buffer], [add_to_children(current, tag_block) | rest])
    else
      to_tree(tokens, buffer, [tag_block | tree])
    end
  end

  def to_tree([{:text, text, _meta} = token | tokens], buffer, tree) do
    # Ignore when it is either a new_line and/or empty spaces.
    if String.trim(text) == "" do
      to_tree(tokens, buffer, tree)
    else
      # Otherwise check the buffer, then adds it to the buffer in case there is
      # one or add to directly to the tree.
      case buffer do
        [tag_block | rest] ->
          to_tree(tokens, [add_to_children(tag_block, token) | rest], tree)

        [] ->
          to_tree(tokens, [token | buffer], tree)
      end
    end
  end

  def to_tree([{:tag_close, _name, _meta} | tokens], [], tree) do
    to_tree(tokens, [], [:tag_close | tree])
  end

  def to_tree([{:tag_close, _name, _meta} | tokens], buffer, [current | rest]) do
    to_tree(tokens, [], [:tag_close, add_to_tag_block(current, buffer) | rest])
  end

  defp build_tag_block({:tag_open, name, attrs, meta}) do
    {:tag_block, name, attrs, meta, []}
  end

  defp add_to_children({:tag_block, name, attrs, meta, children}, tag_block) do
    {:tag_block, name, attrs, meta, [tag_block | children]}
  end

  defp add_to_tag_block({:tag_block, name, attrs, meta, _children}, buffer) do
    {:tag_block, name, attrs, meta, Enum.reverse(buffer)}
  end

  defp tag_block?({:tag_block, _name, _attrs, _meta, _children}), do: true
  defp tag_block?(_token), do: false
end
