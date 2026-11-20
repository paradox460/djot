defmodule DjotTest do
  use ExUnit.Case, async: true
  doctest Djot
  doctest Djot.Attributes
  doctest Djot.Document
  doctest Djot.Sigil

  @test_doc """
  Hello world

  - List item

    - Indented list item

    - Another indented list item
  """

  @corpus """
  # Title

  Para with _e_ *s* {=m=} {+i+} {-d-} H~2~O x^2^ [sp]{.c} [link](http://a.b) <https://x.y>
  [ref][r] ![img](i.png) note[^1] `v` $`x` $$`y` :smile: "q" 'q' ... -- --- a\\ b\\
  hard

  [r]: http://ref.example

  [^1]: Footnote text.

  ## Sub

  - a
  - b

  a) one
  b) two

  - [ ] t1
  - [x] t2

  : term

    def

  | a | b |
  |:--|--:|
  | 1 | 2 |
  ^ cap

  > quote

  ::: warn
  div
  :::

  {#hr}
  ---

  ``` elixir
  code
  ```

  ```=html
  <b>raw</b>
  ```
  """

  describe "renderers" do
    test "default" do
      expected =
        "<p>Hello world</p>\n<ul>\n<li>\nList item\n<ul>\n<li>\n<p>Indented list item</p>\n</li>\n<li>\n<p>Another indented list item</p>\n</li>\n</ul>\n</li>\n</ul>\n"

      assert {:ok, ^expected} = Djot.to_html(@test_doc)
    end

    test "minified" do
      expected =
        "<p>Hello world</p><ul><li>List item<ul><li><p>Indented list item</p></li><li><p>Another indented list item</p></li></ul></li></ul>"

      assert {:ok, ^expected} = Djot.to_html(@test_doc, render: [renderer: :minified])
    end

    test "indented" do
      expected =
        "<p>Hello world</p>\n<ul>\n\t<li>\n\t\tList item\n\t\t<ul>\n\t\t\t<li>\n\t\t\t\t<p>Indented list item</p>\n\t\t\t</li>\n\t\t\t<li>\n\t\t\t\t<p>Another indented list item</p>\n\t\t\t</li>\n\t\t</ul>\n\t</li>\n</ul>\n"

      assert {:ok, ^expected} = Djot.to_html(@test_doc, render: [renderer: :indented])
    end

    test "indented with indent_string and indent_initial_level" do
      expected =
        "foofoo<p>Hello world</p>\nfoofoo<ul>\nfoofoofoo<li>\nfoofoofoofooList item\nfoofoofoofoo<ul>\nfoofoofoofoofoo<li>\nfoofoofoofoofoofoo<p>Indented list item</p>\nfoofoofoofoofoo</li>\nfoofoofoofoofoo<li>\nfoofoofoofoofoofoo<p>Another indented list item</p>\nfoofoofoofoofoo</li>\nfoofoofoofoo</ul>\nfoofoofoo</li>\nfoofoo</ul>\n"

      assert {:ok, ^expected} =
               Djot.to_html(@test_doc,
                 render: [renderer: :indented, indent_initial_level: 2, indent_string: "foo"]
               )
    end

    test "render options on a document" do
      doc = Djot.parse_document!("Hello World")
      assert Djot.to_html!(doc, render: [renderer: :minified]) == "<p>Hello World</p>"
    end
  end

  describe "AST round trip" do
    for renderer <- [:default, :minified, :indented] do
      test "#{renderer} renderer matches the source path" do
        opts = [render: [renderer: unquote(renderer)]]
        fast = Djot.to_html!(@corpus, opts)
        assert fast == Djot.to_html!(Djot.parse_document!(@corpus), opts)
        assert fast =~ "<dl>"
        assert fast =~ ~s(<li id="fn1">)
      end
    end

    test "attribute values with backslashes survive" do
      src = ~S({title="a\\b\"c"}) <> "\npara\n"
      assert Djot.to_html!(src) == Djot.to_html!(Djot.parse_document!(src))
    end

    test "invalid nodes return an error" do
      assert {:error, %Djot.DjotError{reason: "invalid djot node"}} =
               Djot.to_html(Djot.Document.wrap(%{not: :a_node}))
    end
  end

  test "parse shape" do
    assert [
             %Djot.Section{
               id: "Hi",
               nodes: [
                 %Djot.Heading{level: 1, has_section: true, nodes: [%Djot.Text{literal: "Hi"}]},
                 %Djot.Paragraph{
                   nodes: [
                     %Djot.Text{literal: "Hello "},
                     %Djot.Strong{nodes: [%Djot.Text{literal: "world"}]}
                   ]
                 }
               ]
             }
           ] = Djot.parse_document!("# Hi\n\nHello *world*").nodes
  end

  test "Djot.Raw renders verbatim in block and inline position" do
    doc =
      Djot.Document.wrap([
        %Djot.Raw{literal: "<x-block></x-block>"},
        %Djot.Paragraph{nodes: [%Djot.Text{literal: "a"}, %Djot.Raw{literal: "<i>b</i>"}]}
      ])

    assert Djot.to_html!(doc) == "<x-block></x-block>\n<p>a<i>b</i></p>\n"
  end

  describe "~DJ sigil" do
    use Djot

    test "HTML modifier" do
      assert ~DJ"*a*"HTML == "<p><strong>a</strong></p>\n"
    end

    test "no modifier returns a document" do
      assert %Djot.Document{nodes: [%Djot.Paragraph{}]} = ~DJ"x"
    end
  end
end
