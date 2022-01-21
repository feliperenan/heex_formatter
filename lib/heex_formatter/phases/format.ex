defmodule HeexFormatter.Phases.Format do
  @moduledoc """
  Transform the given tokens into a string formatting it.

  Given the following nodes:

  [
    {:tag_open, "section", [], %{column: 1, line: 1}},
    {:tag_open, "div", [], %{column: 1, line: 2}},
    {:tag_open, "h1", [], %{column: 1, line: 3}},
    {:text, "Hello", %{column_end: 10, line_end: 3}},
    {:tag_close, "h1", %{column: 10, line: 3}},
    {:tag_close, "div", %{column: 1, line: 4}},
    {:tag_close, "section", %{column: 1, line: 5}}
  ]

  The following string will be returned:

  "<section>\n  <div>\n    <h1>\n      Hello\n    </h1>\n  </div>\n</section>\n"

  Notice that this string is formatted. So this is supposed to be the last
  step before writting it to a file.
  """

  # Use 2 spaces for a tab
  @tab "  "

  # Line length of opening tags before splitting attributes onto their own line
  @default_line_length 98

  @spec run(list(), Keyword.t()) :: String.t()
  def run(tokens, _opts) do
    initial_state = %{html: "", previous_token: nil, indentation: 0}

    result =
      Enum.reduce(tokens, initial_state, fn token, state ->
        new_state = token_to_string(token, state)

        # Set the previous token so we can check it to know how the current tag should
        # be formatted.
        %{new_state | previous_token: token}
      end)

    # That is because we are adding "\n" everytime a tag is open. Then we need to extract
    # "\n" from the first line and put this in the end of the line.
    "\n" <> html = result.html
    html <> "\n"
  end

  defp token_to_string({:tag_open, tag, attrs, meta} = node, state) do
    self_closed? = Map.get(meta, :self_close, false)
    indent = indent_expression(state.indentation)

    tag_opened =
      if put_attrs_in_separeted_lines?(node) do
        tag_prefix = "#{indent}<#{tag}\n"
        tag_suffix = if self_closed?, do: "\n#{indent}/>", else: "\n#{indent}>"
        indent_attrs = indent_expression(state.indentation + 1)

        attrs_with_new_lines =
          Enum.map_join(attrs, "\n", &"#{indent_attrs}#{render_attribute(&1)}")

        tag_prefix <> attrs_with_new_lines <> tag_suffix
      else
        attrs_string =
          attrs
          |> Enum.map(&render_attribute/1)
          |> Enum.intersperse(" ")
          |> Enum.join("")

        tag_prefix = String.trim("<#{tag} #{attrs_string}")

        if self_closed? do
          "#{indent}#{tag_prefix} />"
        else
          "#{indent}#{tag_prefix}>"
        end
      end

    indentation = if self_closed?, do: state.indentation, else: state.indentation + 1

    %{state | html: state.html <> "\n" <> tag_opened, indentation: indentation}
  end

  defp token_to_string({:text, text, _meta}, state) do
    text =
      case state.previous_token do
        {:eex_tag_render, _tag, _meta} ->
          " " <> String.trim(text)

        _token ->
          indent = indent_expression(state.indentation)
          "\n" <> indent <> String.trim(text)
      end

    %{state | html: state.html <> text}
  end

  defp token_to_string({:tag_close, tag, _meta}, state) do
    indentation = state.indentation - 1
    tag_closed = indent_expression("</#{tag}>", indentation)

    %{state | html: state.html <> tag_closed, indentation: indentation}
  end

  # eex_tag_render represents <%=
  defp token_to_string({:eex_tag_render, tag, meta}, state) do
    case state.previous_token do
      {:text, _text, _meta} ->
        eex_tag = " " <> tag
        %{state | html: state.html <> eex_tag}

      _token ->
        indentation = if meta.block?, do: state.indentation + 1, else: state.indentation
        eex_tag = indent_expression(tag, state.indentation)

        %{state | html: state.html <> eex_tag, indentation: indentation}
    end
  end

  # eex_tag represents <% %>
  defp token_to_string({:eex_tag, "<% else %>" = tag, _meta}, state) do
    eex_tag = indent_expression(tag, state.indentation - 1)

    %{state | html: state.html <> eex_tag}
  end

  defp token_to_string({:eex_tag, "<% end %>" = tag, _meta}, state) do
    indentation = state.indentation - 1
    eex_tag = indent_expression(tag, indentation)

    %{state | html: state.html <> eex_tag, indentation: indentation}
  end

  defp token_to_string({:eex_tag, tag, _meta}, state) do
    case state.previous_token do
      {type, _tag, _meta} when type in [:eex_tag_render, :eex_tag] ->
        eex_tag = indent_expression(tag, state.indentation - 1)

        %{state | html: state.html <> eex_tag}

      _token ->
        indentation = state.indentation - 1
        eex_tag = indent_expression(tag, indentation)

        %{state | html: state.html <> eex_tag, indentation: indentation}
    end
  end

  # Helper for indenting the given expression according to the given indentation.
  #
  # Examples
  #
  #    iex> indent_expression("<%= @user.name %>", 1)
  #    "\n  <%= @user.name %>"
  defp indent_expression(expression, indentation) do
    "\n" <> String.duplicate(@tab, indentation) <> expression
  end

  # Helper for duplicating `@tab` so it can be used as indentation.
  #
  # Examples
  #
  #    iex> indent_expression(2)
  #    "  "
  defp indent_expression(indentation) do
    String.duplicate(@tab, indentation)
  end

  defp put_attrs_in_separeted_lines?({:tag_open, tag, attrs, meta}) do
    # TODO: accept max_line_length as option.
    max_line_length = @default_line_length
    self_closed? = Map.get(meta, :self_close, false)

    # Calculate attrs length. It considers 1 space between each attribute, that
    # is why it adds + 1 for each attribute.
    attrs_length =
      attrs
      |> Enum.map(fn attr ->
        attr
        |> render_attribute()
        |> String.length()
        |> then(&(&1 + 1))
      end)
      |> Enum.sum()

    # Calculate the length of tag + attrs + spaces.
    length_on_same_line = attrs_length + String.length(tag) + if self_closed?, do: 4, else: 2

    if length(attrs) > 1 do
      length_on_same_line > max_line_length
    else
      false
    end
  end

  defp render_attribute(attr) do
    case attr do
      {:root, {:expr, expr, _}} ->
        ~s({#{expr}})

      {attr, {:string, value, _meta}} ->
        ~s(#{attr}="#{value}")

      {attr, {:expr, value, _meta}} ->
        ~s(#{attr}={#{value}})

      {attr, {_, value, _meta}} ->
        ~s(#{attr}=#{value})

      {attr, nil} ->
        ~s(#{attr})
    end
  end
end
