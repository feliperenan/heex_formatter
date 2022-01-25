defmodule HeexFormatter.Formatter do
  @moduledoc false

  # Use 2 spaces for a tab
  @tab "  "

  # Line length of opening tags before splitting attributes onto their own line
  @default_line_length 98

  @doc """
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
  step before writing it to a file.
  """
  def format(tokens, opts) do
    initial_state = %{
      buffer: [],
      previous_token: nil,
      indentation: 0,
      line_length: opts[:heex_line_length] || opts[:line_length] || @default_line_length,
      formatter_opts: opts,
      mode: :normal
    }

    tokens
    |> Enum.reduce(initial_state, fn token, state ->
      new_state = token_to_string(token, state)
      %{new_state | previous_token: token}
    end)
    |> buffer_to_string()
  end

  defp buffer_to_string(state) do
    state.buffer
    |> Enum.reverse()
    |> IO.iodata_to_binary()
    |> then(&(&1 <> "\n"))
  end

  defp token_to_string({:tag_open, tag, attrs, meta} = node, state) do
    self_closed? = Map.get(meta, :self_close, false)
    indent = indent_expression(state.indentation)

    tag_opened =
      if put_attrs_in_separeted_lines?(node, state.line_length) do
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

    mode = if tag in ~w(script style code pre), do: String.to_existing_atom(tag), else: :normal
    indentation = if self_closed?, do: state.indentation, else: state.indentation + 1
    line_break = may_add_line_break(:tag_open, state.previous_token)
    buffer = [line_break <> tag_opened | state.buffer]

    %{state | buffer: buffer, indentation: indentation, mode: mode}
  end

  defp token_to_string({tag, text, _meta}, %{mode: mode} = state)
       when tag in ~w(text eex_tag eex_tag_render)a and mode in ~w(script style code pre comment)a do
    %{state | buffer: [text | state.buffer]}
  end

  defp token_to_string({:text, text, %{context: context}}, state) when is_list(context) do
    mode = if :comment_start in context, do: :comment, else: :normal

    %{state | buffer: [text | state.buffer], mode: mode}
  end

  defp token_to_string({:text, text, _meta}, state) do
    text =
      case state.previous_token do
        {:eex_tag_render, _tag, _meta} ->
          " " <> String.trim(text)

        # In case the previous token is a tag open, this will check if the text
        # should either go to the current line or next line. Tag with attributes
        # always go to the next line.
        {:tag_open, _tag, attrs, _meta} ->
          text = String.trim(text)

          if String.length(text) < state.line_length and Enum.empty?(attrs) do
            text
          else
            indent = indent_expression(state.indentation)
            "\n" <> indent <> text
          end

        _token ->
          indent = indent_expression(state.indentation)
          "\n" <> indent <> String.trim(text)
      end

    %{state | buffer: [text | state.buffer]}
  end

  defp token_to_string({:tag_close, tag, _meta}, %{mode: mode} = state)
       when mode != :normal do
    indentation = state.indentation - 1
    tag_closed = "#{indent_expression(indentation)}</#{tag}>"
    %{state | buffer: [tag_closed | state.buffer], indentation: indentation, mode: :normal}
  end

  defp token_to_string({:tag_close, tag, _meta}, state) do
    indentation = state.indentation - 1

    tag_closed =
      case state.previous_token do
        {:text, _text, _meta} ->
          if tag_contains_line_break?(state.buffer, tag) do
            indent_expression("</#{tag}>", indentation)
          else
            "</#{tag}>"
          end

        # In case the previous token is a tag_open and it is the same tag, we
        # don't want to break lines since this tag has not content at all.
        {:tag_open, ^tag, _attrs, _meta} ->
          "</#{tag}>"

        _token ->
          indent_expression("</#{tag}>", indentation)
      end

    mode = if tag in ~w(script style code pre), do: String.to_atom(tag), else: :normal

    %{state | buffer: [tag_closed | state.buffer], indentation: indentation, mode: mode}
  end

  defp token_to_string({:eex_tag_render, tag, meta}, state) do
    formatted_tag = format_eex(tag, state)

    case state.previous_token do
      {:text, _text, _meta} ->
        eex_tag = " " <> formatted_tag
        %{state | buffer: [eex_tag | state.buffer]}

      nil ->
        %{state | buffer: [formatted_tag | state.buffer]}

      _token ->
        indentation = if meta.block?, do: state.indentation + 1, else: state.indentation

        eex_tag = indent_expression(formatted_tag, state.indentation)

        %{state | buffer: [eex_tag | state.buffer], indentation: indentation}
    end
  end

  # eex_tag represents <% %>
  defp token_to_string({:eex_tag, "<% else %>" = tag, _meta}, state) do
    eex_tag = indent_expression(tag, state.indentation - 1)

    %{state | buffer: [eex_tag | state.buffer]}
  end

  defp token_to_string({:eex_tag, "<% end %>" = tag, _meta}, state) do
    indentation = state.indentation - 1
    eex_tag = indent_expression(tag, indentation)

    %{state | buffer: [eex_tag | state.buffer], indentation: indentation}
  end

  # Handle eex_tag such as <% {:ok, result} -> %> present within case statements
  # or cond.
  defp token_to_string({:eex_tag, tag, %{block?: true}}, state) do
    eex_tag = indent_expression(tag, state.indentation - 1)
    %{state | buffer: [eex_tag | state.buffer]}
  end

  defp token_to_string({:eex_tag, tag, _meta}, state) do
    case state.previous_token do
      {type, _tag, _meta} when type in [:eex_tag_render, :eex_tag] ->
        eex_tag = indent_expression(tag, state.indentation)

        %{state | buffer: [eex_tag | state.buffer]}

      nil ->
        %{state | buffer: [tag | state.buffer]}

      _token ->
        indentation = state.indentation - 1
        eex_tag = indent_expression(tag, indentation)

        %{state | buffer: [eex_tag | state.buffer], indentation: indentation}
    end
  end

  # Helper for indenting the given expression according to the given indentation.
  #
  # Examples
  #
  #    iex> indent_expression("<%= @user.name %>", 1)
  #    "\n  <%= @user.name %>"
  defp indent_expression(expression, indentation) do
    "\n" <> indent_expression(indentation) <> expression
  end

  # Helper for duplicating `@tab` so it can be used as indentation.
  #
  # Examples
  #
  #    iex> indent_expression(2)
  #    "  "
  defp indent_expression(indentation) do
    String.duplicate(@tab, max(0, indentation))
  end

  defp put_attrs_in_separeted_lines?({:tag_open, tag, attrs, meta}, max_line_length) do
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

  # Format a given eex code to match provided indentation in HEEx template.
  #
  # Given the following code:
  #
  # "form_for @changeset, Routes.user_path(@conn, :create), [class: "w-full", phx_change: "on_change"], fn f ->"
  #
  # The following string will be returned:
  #
  # <%= form_for @changeset,
  #            Routes.user_path(@conn, :create),
  #            [class: \"w-full\", phx_change: \"on_change\"],
  #            fn f -> %>
  defp format_eex(code, state) do
    code = String.replace(code, ["<%= ", " %>"], "")

    formatted_code =
      cond do
        code =~ ~r/\sdo\z/m ->
          format_ends_with_do(code, state.formatter_opts)

        String.ends_with?(code, "->") ->
          format_ends_with_priv_fn(code, state.formatter_opts)

        true ->
          run_formatter(code, state.formatter_opts)
      end

    formatted_code =
      Enum.join(
        String.split(formatted_code, "\n"),
        "\n" <> String.duplicate(@tab, state.indentation)
      )

    "<%= #{formatted_code} %>"
  end

  defp format_ends_with_do(code, formatter_opts) do
    (code <> "\nend")
    |> run_formatter(formatter_opts)
    |> String.replace_trailing("\nend", "")
  end

  defp format_ends_with_priv_fn(code, formatter_opts) do
    (code <> "\nnil\nend")
    |> run_formatter(formatter_opts)
    |> String.trim()
    |> remove_added_code()
    |> String.split("\n")
    |> Enum.slice(0..-3)
    |> Enum.join("\n")
  end

  defp remove_added_code(code) do
    if String.ends_with?(code, ")") do
      fn_name_length = String.split(code, "(") |> Enum.at(0) |> String.length()
      extra_space = String.duplicate(" ", fn_name_length + 1)

      code
      |> String.replace("(\n ", "", global: false)
      |> String.replace("\n  ", "\n" <> extra_space)
      |> String.replace_trailing("\n)", "")
    else
      code
    end
  end

  defp run_formatter(code, opts) do
    code
    |> Code.format_string!(opts)
    |> IO.iodata_to_binary()
  end

  # Check if the given tag contains line breaks in the given html state.
  #
  # Useful to know if we should either close the tag in the current line or
  # in the next line. For instance:
  #
  #   should close the tag in the current line.
  #   <p>My title
  #
  #   should close the tag in the next line.
  #   <p class="some-class">  \nShould break line
  defp tag_contains_line_break?(buffer, tag) do
    current_tag = current_tag(buffer, [], tag)

    String.contains?(current_tag, "\n")
  end

  defp current_tag([head | rest], buffer, tag) do
    if String.contains?(head, "<#{tag}>") do
      current_tag([], buffer, tag)
    else
      current_tag(rest, [head | buffer], tag)
    end
  end

  defp current_tag([], buffer, _tag), do: IO.iodata_to_binary(buffer)

  # Returns an empty space or a "\n".
  #
  # * For tag_open, the genernal rule is that is should break line. The exception
  #   is when there is no previous_token or the previous_token is a HTML comment.
  defp may_add_line_break(:tag_open, nil), do: ""

  defp may_add_line_break(:tag_open, {:text, _text, %{context: context}})
       when is_list(context),
       do: ""

  defp may_add_line_break(:tag_open, {:text, text, _meta}) do
    html_comment? = String.contains?(text, "<!--") and String.contains?(text, "-->")
    if html_comment?, do: "", else: "\n"
  end

  defp may_add_line_break(:tag_open, _token), do: "\n"
end