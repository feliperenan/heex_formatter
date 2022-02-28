# HeexFormatter

[![ElixirCI](https://github.com/feliperenan/heex_formatter/actions/workflows/elixir.yml/badge.svg)](https://github.com/feliperenan/heex_formatter/actions/workflows/elixir.yml)

A code formatter for Heex templates.

:warning: This project is still in the alpha stage. There are several cases yet to be handled.

![Example animation](examples/example.gif)

## Pre-requisites

* Elixir 1.13
* Phoenix Live View 1.17.7

## Installation

Add `:heex_formatter` as dependency in your `mix.exs` file.

```elixir
defp deps do
  [
    # ...
    {:heex_formatter, github: "feliperenan/heex_formatter"},
  ]
end
```

Add it as plugin to your project's `.formatter` file and make sure to put the `heex` extension in the `inputs` option.

```elixir
[
  plugins: [HeexFormatter],
  inputs: [
    # ...
    "*.{heex,ex,exs}",
    "{config,lib,test}/**/*.{heex,ex,exs}"
  ],
]
```

Get the dependency.

```elixir
mix deps.get
```

Compile the project.

```elixir
mix compile
```

Run the formatter.

```elixir
mix format
```

## Options

### line_length

The Elixir formatter defaults to a maximum line length of 98 characters, which can be overwritten with the `line_length` option in your `.formatter` file.

Set `heex_line_length` to only set the line length for the heex formatter.

```elixir
[
  # ...omitted
  heex_line_length: 300
]
```

Inspired by [Surface Formatter](https://github.com/surface-ui/surface_formatter).
