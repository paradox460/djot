defmodule Djot.HEEx do
  @moduledoc false
  # Compiles rendered Djot HTML as a HEEx template. Compile helper adapted
  # from MDEx (MIT, https://github.com/leandrocp/mdex).

  @compile {:no_warn_undefined, [Phoenix.LiveView.TagEngine, Phoenix.LiveView.HTMLEngine]}

  alias Djot.Document
  alias Djot.HEEx.Preprocessor

  def live_view_available?, do: Code.ensure_loaded?(Phoenix.LiveView.TagEngine)

  @doc false
  # Braces as entities so HEEx reads them as text, not expressions.
  def escape_braces(html),
    do: html |> String.replace("{", "&lbrace;") |> String.replace("}", "&rbrace;")

  @spec render_template(Djot.source(), keyword()) :: {:ok, String.t()} | {:error, Exception.t()}
  def render_template(source_or_doc, opts) do
    {_assigns, opts} = Keyword.pop(opts, :assigns)
    doc = Djot.document(source_or_doc, opts)

    if Document.get_option(doc, :sanitize) do
      {:error,
       %Djot.DjotError{
         reason: :sanitize_unsupported_in_heex,
         message: "sanitize: cannot be combined with to_heex; ammonia would decode brace escapes"
       }}
    else
      doc =
        if is_binary(doc.source), do: %{doc | source: Preprocessor.rewrite(doc.source)}, else: doc

      Djot.Renderer.render(doc, heex: true)
    end
  end

  def compile(html, caller) do
    Phoenix.LiveView.TagEngine.compile(html,
      file: caller.file,
      line: caller.line,
      caller: caller,
      tag_handler: Phoenix.LiveView.HTMLEngine
    )
  end

  def __to_heex__(source_or_doc, opts, caller) do
    {assigns, opts} = Keyword.pop(opts, :assigns, %{})

    doc_assigns =
      case source_or_doc do
        %Document{} = doc -> Document.get_option(doc, :assigns, %{})
        _ -> %{}
      end

    assigns =
      doc_assigns
      |> Map.merge(Map.new(assigns))

    with {:ok, html} <- render_template(source_or_doc, opts),
         {:ok, ast} <- safe_compile(html, caller) do
      {rendered, _} =
        Code.eval_quoted(ast, [assigns: assigns], Macro.Env.prune_compile_info(caller))

      {:ok, rendered}
    end
  end

  def __to_heex__!(source_or_doc, opts, caller) do
    case __to_heex__(source_or_doc, opts, caller) do
      {:ok, rendered} -> rendered
      {:error, exception} -> raise exception
    end
  end

  defp safe_compile(html, caller) do
    {:ok, compile(html, caller)}
  rescue
    e -> {:error, e}
  end
end
