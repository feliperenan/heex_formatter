defmodule Eef.Render do
  @moduledoc false

  @tab "  "

  def as_string(nodes, opts \\ [indentation: 0]) do
    {str, _opts} =
      nodes
      |> Enum.reduce(
        {"", opts},
        fn
          {elem, name, atttributes, meta}, {acc, opts} when is_list(atttributes) ->
            {acc <> node_to_string({elem, name, atttributes, meta}, opts), opts}

          {:element, name, atttributes, children, meta}, {acc, opts}
          when is_list(atttributes) and is_list(children) ->
            {acc <> element_to_string(name, atttributes, children, meta, opts), opts}

          {elem, name, meta}, {acc, opts} ->
            {acc <> node_to_string({elem, name, [], meta}, opts), opts}

          {elem, name}, {acc, opts} ->
            {acc <> node_to_string({elem, name, [], %{}}, opts), opts}

          :indent, {acc, opts} ->
            {acc, inc_indent(opts)}
        end
      )

    str
  end

  def element_to_string(element, attributes, [], _meta, opts) do
    content = "#{element} #{attributes_to_string(attributes, inc_indent(opts))}" |> String.trim()
    "#{indentation(opts)}<#{content}>\n\n"
  end

  def element_to_string(element, attributes, children, _meta, opts) do
    content = "#{element} #{attributes_to_string(attributes, inc_indent(opts))}" |> String.trim()
    children = as_string(children, inc_indent(opts))

    "#{indentation(opts)}<#{content}>\n#{@tab}#{children}\n#{indentation(opts)}</#{element}>\n"
  end

  def node_to_string({:text, text, _attributes, _meta}, opts) do
    (indentation(opts) <> text) |> String.trim()
  end

  defp attributes_to_string(attributes, opts) do
    attrs = attributes |> Enum.map(&attribute_to_string/1)

    if(length(attributes) > 2) do
      "\n#{indentation(opts)}" <> Enum.join(attrs, "\n#{indentation(opts)}")
    else
      Enum.join(attrs, " ")
    end
  end

  defp attribute_to_string({key, value}) do
    "#{key}=#{attribute_value_to_string(value)}"
  end

  defp attribute_value_to_string({:string, value, _}) do
    "\"#{value}\""
  end

  defp attribute_value_to_string({:expr, value, _}) do
    case Code.string_to_quoted(value) do
      {:ok, ast} -> "{#{Macro.to_string(ast)}}"
      _ -> "{#{value}}"
    end
  end

  defp indentation(opts) do
    ind = Keyword.get(opts, :indentation, 0)
    String.duplicate(@tab, ind)
  end

  defp inc_indent(opts), do: Keyword.update(opts, :indentation, 0, fn c -> c + 1 end)

  defp dec_indent(opts),
    do:
      Keyword.update(opts, :indentation, 0, fn
        0 -> 0
        c -> c - 1
      end)
end
