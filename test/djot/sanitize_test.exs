defmodule Djot.SanitizeTest do
  use ExUnit.Case, async: true

  @default Djot.Document.default_sanitize_options()

  test "removes scripts and event handlers from raw html" do
    src = "```=html\n<script>x</script><b onclick=\"y\">hi</b>\n```\n"
    html = Djot.to_html!(src, sanitize: @default)
    assert html =~ "<b>hi</b>"
    refute html =~ "script"
    refute html =~ "onclick"
  end

  test "keeps djot footnotes, headings, and task lists" do
    src = "# T\n\nnote[^1]\n\n- [x] done\n\n[^1]: text\n"
    html = Djot.to_html!(src, sanitize: @default)
    assert html =~ ~s(id="fn1")
    assert html =~ ~s(href="#fn1")
    assert html =~ ~s(<section id="T">)
    assert html =~ ~s(type="checkbox")
  end

  test "sanitize options merge over defaults" do
    html = Djot.to_html!("```=html\n<b>x</b>\n```\n", sanitize: [rm_tags: ["b"]])
    refute html =~ "<b>"
  end

  test "invalid url_relative base is an error" do
    assert {:error, %Djot.DjotError{reason: "invalid url_relative base: " <> _}} =
             Djot.to_html("[a](b)", sanitize: [url_relative: {:rewrite_with_base, "not a url"}])
  end

  test "safe_html" do
    assert Djot.safe_html("<a>&</a>", sanitize: nil, escape: true) == "&lt;a&gt;&amp;&lt;/a&gt;"
    assert Djot.safe_html("<i onclick=x>a</i>") == "<i>a</i>"
  end
end
