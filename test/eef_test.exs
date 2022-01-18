defmodule EefTest do
  use ExUnit.Case
  doctest Eef

  test "greets the world" do
    str = """
    <div class={@class} title="My div">
      <SomeModule.some_func_compoent attr1="some string" attr2={@some_expression} {@other_dynamic_attrs}>
      <.some_local_func_compoent attr1="some string">
    </div>
    """

    assert Eef.hello() == :world
  end
end
