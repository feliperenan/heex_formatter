defmodule HeexFormatter.Core.EexFormatter do
  @moduledoc """
  Format eex syntax.
  """
  @tab HeexFormatter.Phases.Format.tab()
  def format(code, opts \\ []) do
    indentation = Keyword.get(opts, :indentation, 0)

    type = if String.starts_with?(code, "<%="), do: :eex_tag_render, else: :eex_tag

    code = String.replace(code, ["<%= ", "<% ", " %>"], "")

    formatted_code =
      cond do
        code =~ ~r/\sdo\z/m -> format_ends_with_do(code, [])
        String.ends_with?(code, "->") -> format_ends_with_priv_fn(code, [])
        true -> run_formatter(code, [])
      end

    formatted_code =
      formatted_code
      |> String.split("\n")
      |> Enum.join("\n" <> String.duplicate(@tab, indentation))

    write_eex_symbols(formatted_code, type)
  end

  defp write_eex_symbols(code, :eex_tag), do: "<% #{code} %>"
  defp write_eex_symbols(code, :eex_tag_render), do: "<%= #{code} %>"

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
end
