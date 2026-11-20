defmodule Djot.StreamTest do
  use ExUnit.Case, async: true

  test "emits changed blocks by id" do
    result =
      ["# Hel", "lo\n\nPara", "graph\n"]
      |> Djot.stream()
      |> Enum.map(fn {id, doc} -> {id, Djot.to_html!(doc)} end)

    assert result == [
             {0, "<h1 id=\"Hel\">Hel</h1>\n"},
             {0, "<h1 id=\"Hello\">Hello</h1>\n"},
             {1, "<p>Para</p>\n"},
             {1, "<p>Paragraph</p>\n"}
           ]
  end

  test "per-block documents carry their stream id" do
    plugin = fn doc ->
      Djot.Document.append_steps(doc,
        tag: fn d ->
          %{id: id} = Djot.Document.get_private(d, :stream)

          Djot.Document.put_node_in_document_root(
            d,
            %Djot.Raw{literal: "<b id=\"b-#{id}\"></b>"},
            :bottom
          )
        end
      )
    end

    assert ["a\n\nb"]
           |> Djot.stream(plugins: [plugin])
           |> Enum.map(fn {id, d} -> {id, Djot.to_html!(d)} end) == [
             {0, "<p>a</p>\n<b id=\"b-0\"></b>\n"},
             {1, "<p>b</p>\n<b id=\"b-1\"></b>\n"}
           ]
  end

  test "plugins attach once and run per block" do
    plugin = fn doc ->
      Djot.Document.append_steps(doc,
        up: fn d ->
          Djot.Document.update_nodes(d, Djot.Text, &%{&1 | literal: String.upcase(&1.literal)})
        end
      )
    end

    assert [{0, doc}] = ["hi"] |> Djot.stream(plugins: [plugin]) |> Enum.to_list()
    assert Djot.to_html!(doc) == "<p>HI</p>\n"
  end

  test "multi-byte characters split across chunks" do
    assert [{0, doc}] = [<<0xC3>>, <<0xA9>>] |> Djot.stream() |> Enum.to_list()
    assert doc[Djot.Text] == [%Djot.Text{literal: "é"}]
  end

  test "incomplete UTF-8 at the end raises" do
    assert_raise ArgumentError, "incomplete UTF-8 at end of djot stream", fn ->
      [<<0xC3>>] |> Djot.stream() |> Enum.to_list()
    end
  end

  test "rejects :source" do
    assert_raise ArgumentError, fn -> Djot.stream(["x"], source: "y") end
  end
end
