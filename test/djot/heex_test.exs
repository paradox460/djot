defmodule Djot.HEExTest do
  use ExUnit.Case, async: true
  use Djot
  import Phoenix.Component

  alias Djot.HEEx.Preprocessor

  defp to_s(rendered), do: rendered |> Phoenix.HTML.Safe.to_iodata() |> IO.iodata_to_binary()

  describe "preprocessor" do
    test "inline expressions" do
      assert Preprocessor.rewrite("a {@x} b") == "a `{@x}`{=heex} b"
      assert Preprocessor.rewrite("a {@m[\"}\"]} b") == "a `{@m[\"}\"]}`{=heex} b"
      assert Preprocessor.rewrite("a <%= 1 %> b") == "a `<%= 1 %>`{=heex} b"

      assert Preprocessor.rewrite("a <.icon name=\"x\" /> b") ==
               "a `<.icon name=\"x\" />`{=heex} b"
    end

    test "djot attribute and span syntax is untouched" do
      for src <- [
            "[a]{.c}",
            "{=m=}",
            "`{@x}`",
            "{#id}",
            "{key=v}",
            "{_e_}",
            "a { b",
            "\\{@x}",
            "{% c %}"
          ] do
        assert Preprocessor.rewrite(src) == src
      end
    end

    test "block constructs become raw heex blocks" do
      assert Preprocessor.rewrite("text\n<.card title=\"a>b\">\nbody\n</.card>\n") ==
               "text\n\n```=heex\n<.card title=\"a>b\">\n```\n\nbody\n\n```=heex\n</.card>\n```\n\n"
    end

    test "backticks inside constructs widen the fence" do
      assert Preprocessor.rewrite("a {@x <> \"`\"} b") == "a ``{@x <> \"`\"}``{=heex} b"
      assert Preprocessor.rewrite("a <%= \"`\" %> b `x`") == "a ``<%= \"`\" %>``{=heex} b `x`"
    end

    test "fenced code is untouched" do
      src = "```\n<.card>{@x}\n```\n~~~~\n{@y}\n~~~~\n"
      assert Preprocessor.rewrite(src) == src
    end
  end

  describe "~DJ HEEX" do
    test "renders expressions and components" do
      assigns = %{name: "Ann"}

      html =
        to_s(~DJ"""
        Hi {@name}

        <.link href="/x">go</.link>
        """HEEX)

      assert html =~ "Hi Ann"
      assert html =~ ~s(<a href="/x">go</a>)
    end
  end

  describe "to_heex" do
    test "assigns and text braces" do
      # Literal braces render as entities, which browsers display as `{`.
      assert "a { b" |> Djot.to_heex!(assigns: %{}) |> to_s() == "<p>a &lbrace; b</p>"
      html = "Hello {@who} `{code}`" |> Djot.to_heex!(assigns: %{who: "W"}) |> to_s()
      assert html == "<p>Hello W <code>&lbrace;code&rbrace;</code></p>"
    end

    test "highlighted code escapes braces" do
      html =
        "``` elixir\n%{a: 1}\n```\n"
        |> Djot.to_heex!(syntax_highlight: [engine: :syntect])
        |> to_s()

      assert html =~ "%&lbrace;"
      assert html =~ "&rbrace;"
    end

    test "sanitize is rejected" do
      assert {:error, %Djot.DjotError{reason: :sanitize_unsupported_in_heex}} =
               Djot.to_heex("x", sanitize: Djot.Document.default_sanitize_options())
    end

    test "documents" do
      doc = Djot.parse_document!("x") |> Djot.Document.assign(:y, 1)
      assert to_s(Djot.to_heex!(doc)) == "<p>x</p>"
    end

    test "steps see :heex and can emit brace-safe raw html" do
      plugin = fn doc ->
        Djot.Document.append_steps(doc,
          diagram: fn doc ->
            heex? = Djot.Document.get_private(doc, :heex, false)

            Djot.Document.update_nodes(doc, %Djot.CodeBlock{language: "diagram"}, fn block ->
              literal = Djot.safe_html(block.literal, sanitize: nil, escape: true, heex: heex?)
              %Djot.Raw{literal: ~s(<pre class="diagram">#{literal}</pre>)}
            end)
          end
        )
      end

      src = "``` diagram\nA{yes}-->B\n```\n"
      html = src |> Djot.to_heex!(plugins: [plugin]) |> to_s()
      assert html == ~s(<pre class="diagram">A&lbrace;yes&rbrace;--&gt;B\n</pre>)

      assert Djot.to_html!(src, plugins: [plugin]) ==
               ~s(<pre class="diagram">A{yes}--&gt;B\n</pre>\n)
    end
  end
end
