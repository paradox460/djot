defmodule Djot.DocumentTest do
  use ExUnit.Case, async: true

  alias Djot.Document

  defmodule ShoutPlugin do
    alias Djot.Document

    def attach(doc, opts) do
      doc
      |> Document.register_options([:shout])
      |> Document.put_options(opts)
      |> Document.append_steps(shout: &shout/1)
    end

    defp shout(doc) do
      if Document.get_option(doc, :shout) do
        Document.update_nodes(doc, Djot.Text, &%{&1 | literal: String.upcase(&1.literal)})
      else
        doc
      end
    end
  end

  describe "pipeline" do
    test "plugins register options and run steps" do
      assert Djot.to_html!("hi", plugins: [{ShoutPlugin, shout: true}]) == "<p>HI</p>\n"
      assert Djot.to_html!("hi", plugins: [ShoutPlugin]) == "<p>hi</p>\n"
    end

    test "plugins attach before other options in the same call" do
      assert Djot.to_html!("hi", shout: true, plugins: [ShoutPlugin]) == "<p>HI</p>\n"
    end

    test "unknown options raise" do
      assert_raise ArgumentError, "unknown option :nope", fn ->
        Djot.new() |> Document.put_options(nope: 1)
      end
    end

    test "halt stops later steps and the document still renders" do
      html =
        Djot.new(source: "hi")
        |> Document.append_steps(stop: &Document.halt/1, boom: fn _ -> raise "not reached" end)
        |> Djot.to_html!()

      assert html == "<p>hi</p>\n"
    end

    test "halt with an exception returns an error" do
      doc =
        Djot.new(source: "hi")
        |> Document.append_steps(fail: &Document.halt(&1, %RuntimeError{message: "nope"}))

      assert {:error, %RuntimeError{message: "nope"}} = Djot.to_html(doc)
    end

    test "mfa steps receive the document first" do
      doc =
        Djot.new()
        |> Document.append_steps(
          add: {Document, :put_node_in_document_root, [%Djot.Text{literal: "x"}, :bottom]}
        )
        |> Document.prepend_steps(first: {Document, :put_private, [:seen, true]})
        |> Document.run()

      assert doc.nodes == [%Djot.Text{literal: "x"}]
      assert Document.get_private(doc, :seen)
      assert doc.current_steps == []
    end

    test "options merge and validate" do
      doc =
        Djot.new(render: [renderer: :indented])
        |> Document.put_render_options(indent_string: "  ")
        |> Document.assign(:a, 1)
        |> Document.assign(b: 2)

      assert Enum.sort(Document.get_option(doc, :render)) ==
               [indent_initial_level: 0, indent_string: "  ", renderer: :indented]

      assert Document.get_option(doc, :assigns) == %{a: 1, b: 2}

      assert_raise NimbleOptions.ValidationError, fn ->
        Document.put_render_options(doc, renderer: :fancy)
      end

      doc = Document.put_syntax_highlight_options(doc, engine: :syntect, opts: [theme: "x"])
      doc = Document.put_syntax_highlight_options(doc, opts: [pre_class: "p"])

      assert Enum.sort(Document.get_option(doc, :syntax_highlight)) == [
               engine: :syntect,
               opts: [theme: "x", pre_class: "p"]
             ]

      assert doc
             |> Document.put_syntax_highlight_options(nil)
             |> Document.get_option(:syntax_highlight) == nil
    end
  end

  describe "access and enumerable" do
    setup do
      %{doc: Djot.parse_document!("Hello *world* and *more*")}
    end

    test "fetch by module, atom, struct, and function", %{doc: doc} do
      assert [%Djot.Strong{}, %Djot.Strong{}] = doc[Djot.Strong]
      assert Enum.map(doc[:text], & &1.literal) == ["Hello ", "world", " and ", "more"]
      assert [%Djot.Text{literal: "more"}] = doc[%Djot.Text{literal: "more"}]
      assert [%Djot.Paragraph{}] = doc[&match?(%Djot.Paragraph{}, &1)]
      assert doc[Djot.Heading] == nil
      assert %Djot.Document{} = doc[0]
    end

    test "invalid selector raises", %{doc: doc} do
      assert_raise ArgumentError, "invalid selector: nil", fn -> doc[nil] end
    end

    test "pop removes the first match", %{doc: doc} do
      {popped, doc} = pop_in(doc[Djot.Strong])
      assert popped == %Djot.Strong{nodes: [%Djot.Text{literal: "world"}]}
      assert Djot.to_html!(doc) == "<p>Hello  and <strong>more</strong></p>\n"
    end

    test "get_and_update touches the first match", %{doc: doc} do
      {old, doc} = get_and_update_in(doc[Djot.Text], &{&1.literal, %{&1 | literal: "Bye "}})
      assert old == "Hello "
      assert Djot.to_html!(doc) == "<p>Bye <strong>world</strong> and <strong>more</strong></p>\n"
    end

    test "enumerates pre-order including the root", %{doc: doc} do
      assert Enum.count(doc) == 8

      assert [%Djot.Document{}, %Djot.Paragraph{}, %Djot.Text{literal: "Hello "} | _] =
               Enum.to_list(doc)
    end

    test "collectable appends nodes", %{doc: doc} do
      doc = Enum.into([%Djot.Paragraph{nodes: [%Djot.Text{literal: "end"}]}], doc)
      assert List.last(doc.nodes) == %Djot.Paragraph{nodes: [%Djot.Text{literal: "end"}]}
    end
  end
end
