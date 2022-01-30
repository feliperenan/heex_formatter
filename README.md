# HeexFormatter

[![ElixirCI](https://github.com/feliperenan/heex_formatter/actions/workflows/elixir.yml/badge.svg)](https://github.com/feliperenan/heex_formatter/actions/workflows/elixir.yml)

A code formatter for Heex templates.

:warning: This project is still in alpha stage. There are several cases yet to be handled.

![](examples/example.gif)

### Installation

add `:heex_formatter` as dependency

```elixir
defp deps do
  [
    # ...
    {:heex_formatter, github: "feliperenan/heex_formatter"}
  ]
end
```

Add it as plugin to your project `.formatter` file.

```elixir
[
  plugins: [HeexFormatter],
  import_deps: [:ecto, :phoenix],
  inputs: ["*.{heex,ex,exs}", "priv/*/seeds.exs", "{config,lib,test}/**/*.{heex,ex,exs}"],
  subdirectories: ["priv/*/migrations"]
]
```
Now run
```elixir
mix compile
```
### options

#### line_length

The formatter defaults to a maximum line_length of 98 characters, which can be overwritten with the `line_length` option in the `.formatter` file.

Set `heex_line_length` to only set the line:lenght for the heex formatter.

```elixir
[
  # ...omitted
  heex_line_length: 300
]
```

#### Format Tailwind

Optionally, you can enable Tailwind format, which ensures the uniqueness of the classes used on elements and sort them following the order on [tailwind_format.yml](./config/tailwind_format.yml).

Set `format_tailwind` to enable this feature.

```elixir
[
  # ...omitted
  format_tailwind: true
]
```

Inspired by [Surface Formatter](https://github.com/surface-ui/surface_formatter).
