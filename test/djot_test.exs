defmodule DjotTest do
  use ExUnit.Case
  doctest Djot

  @test_doc """
  Hello world

  - List item

    - Indented list item

    - Another indented list item
  """

  describe "with the default formatter" do
    test "outputs spec results" do
      expected =
        "<p>Hello world</p>\n<ul>\n<li>\nList item\n<ul>\n<li>\n<p>Indented list item</p>\n</li>\n<li>\n<p>Another indented list item</p>\n</li>\n</ul>\n</li>\n</ul>\n"

      assert {:ok, ^expected} = Djot.to_html(@test_doc)
    end
  end

  describe "with the minified renderer" do
    test "outputs minified results" do
      expected =
        "<p>Hello world</p><ul><li>List item<ul><li><p>Indented list item</p></li><li><p>Another indented list item</p></li></ul></li></ul>"

      assert {:ok, ^expected} = Djot.to_html(@test_doc, %Djot.Options{renderer: :minified})
    end
  end

  describe "with the indented renderer" do
    test "indents results" do
      expected =
        "<p>Hello world</p>\n<ul>\n\t<li>\n\t\tList item\n\t\t<ul>\n\t\t\t<li>\n\t\t\t\t<p>Indented list item</p>\n\t\t\t</li>\n\t\t\t<li>\n\t\t\t\t<p>Another indented list item</p>\n\t\t\t</li>\n\t\t</ul>\n\t</li>\n</ul>\n"

      assert {:ok, ^expected} = Djot.to_html(@test_doc, %Djot.Options{renderer: :indented})
    end

    test "indents results with custom indent_string" do
      expected =
        "<p>Hello world</p>\n<ul>\nfoo<li>\nfoofooList item\nfoofoo<ul>\nfoofoofoo<li>\nfoofoofoofoo<p>Indented list item</p>\nfoofoofoo</li>\nfoofoofoo<li>\nfoofoofoofoo<p>Another indented list item</p>\nfoofoofoo</li>\nfoofoo</ul>\nfoo</li>\n</ul>\n"

      assert {:ok, ^expected} =
               Djot.to_html(@test_doc, %Djot.Options{renderer: :indented, indent_string: "foo"})
    end

    test "indents results with custom indent_initial_level" do
      expected =
        "\t\t<p>Hello world</p>\n\t\t<ul>\n\t\t\t<li>\n\t\t\t\tList item\n\t\t\t\t<ul>\n\t\t\t\t\t<li>\n\t\t\t\t\t\t<p>Indented list item</p>\n\t\t\t\t\t</li>\n\t\t\t\t\t<li>\n\t\t\t\t\t\t<p>Another indented list item</p>\n\t\t\t\t\t</li>\n\t\t\t\t</ul>\n\t\t\t</li>\n\t\t</ul>\n"

      assert {:ok, ^expected} =
               Djot.to_html(@test_doc, %Djot.Options{renderer: :indented, indent_initial_level: 2})
    end

    test "indents results with custom indent_string and indent_initial_level" do
      expected =
        "foofoo<p>Hello world</p>\nfoofoo<ul>\nfoofoofoo<li>\nfoofoofoofooList item\nfoofoofoofoo<ul>\nfoofoofoofoofoo<li>\nfoofoofoofoofoofoo<p>Indented list item</p>\nfoofoofoofoofoo</li>\nfoofoofoofoofoo<li>\nfoofoofoofoofoofoo<p>Another indented list item</p>\nfoofoofoofoofoo</li>\nfoofoofoofoo</ul>\nfoofoofoo</li>\nfoofoo</ul>\n"

      assert {:ok, ^expected} =
               Djot.to_html(@test_doc, %Djot.Options{
                 renderer: :indented,
                 indent_initial_level: 2,
                 indent_string: "foo"
               })
    end
  end

  describe "has an ergonomic interface around options" do
    test "accepts keyword options" do
      assert {:ok, "<p>Hello World</p>"} = Djot.to_html("Hello World", renderer: :minified)
    end

    test "accepts map options" do
      assert {:ok, "<p>Hello World</p>"} = Djot.to_html("Hello World", %{renderer: :minified})
    end
  end
end
