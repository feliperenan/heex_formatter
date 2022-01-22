# HeexFormatter

[![ElixirCI](https://github.com/feliperenan/heex_formatter/actions/workflows/elixir.yml/badge.svg)](https://github.com/feliperenan/heex_formatter/actions/workflows/elixir.yml)

A code formatter for Heex tamplates.

:warning: This project is still in alpha stage. There are serveral cases yet to be handled.

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
  inputs: ["*.{ex,exs}", "priv/*/seeds.exs", "{config,lib,test}/**/*.{ex,exs}"],
  subdirectories: ["priv/*/migrations"]
]
```
Now run 
```elixir
mix compile
```
### options

#### line_lenght

The formatter default the a maximum line_length of 98 characters, which can be overwritten with the `line_lenght` option in the `.formatter` file.

Set `heex_line_length` to only set the line:lenght for the heex formatter.

```elixir
[
  plugins: [HeexFormatter],
  inputs: ["{config,lib,test}/**/*.{ex,exs}"],
  heex_line_length: 300
]
```

Inspired by [Surface Formatter](https://github.com/surface-ui/surface_formatter).
