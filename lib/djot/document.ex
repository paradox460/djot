defmodule Djot.Document do
  @moduledoc """
  A Djot document: a tree of nodes plus a Req-like pipeline of options and steps.

  The API mirrors `MDEx.Document` (MDEx 0.14) so plugins port mechanically.

  ## Tree

  `nodes` holds the top-level blocks (see `Djot.Section`, `Djot.Paragraph`, …).
  Documents and nodes implement `Access` and `Enumerable`:

      iex> doc = Djot.parse_document!("Hello *world*")
      iex> doc[Djot.Strong]
      [%Djot.Strong{nodes: [%Djot.Text{literal: "world"}]}]
      iex> doc[:text] |> Enum.map(& &1.literal)
      ["Hello ", "world"]

  Selectors are a node module, a bare atom (`:strong` → `Djot.Strong`), a struct
  pattern where non-default fields must match (`%Djot.Heading{level: 2}`), a
  1-arity predicate, or an integer index into the pre-order walk.

  ## Pipeline

  Plugins are modules with an `attach/2` function (or 1-arity functions) that
  register options, put options, and append steps. A step is a 1-arity function
  or `{module, function, args}` that receives the document and returns it, or
  returns `halt/2`'s `{document, exception}`.

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

      Djot.to_html!("hi", plugins: [{ShoutPlugin, shout: true}])
      #=> "<p>HI</p>\\n"

  ### Private keys set by Djot

  Steps can read these with `get_private/3`:

    * `:heex` - `true` while rendering for `Djot.to_heex/2` or `~DJ"..."HEEX`.
      `Djot.Raw` is written verbatim, so braces in element content would be
      read as HEEx expressions; build such HTML with `Djot.safe_html(html, heex: true)`.
    * `:stream` - `%{id: id}` on each per-block document built by `Djot.stream/2`.
      Plugins that inject page-level content (scripts, styles) should skip it
      (load that from the page layout instead), and include the id in element
      ids so they stay unique across blocks.

  ## Options

  `:render`, `:syntax_highlight`, `:sanitize`, `:plugins`, and `:assigns`; see `Djot.new/1`.
  """

  use Djot.Document.Access

  alias Djot.Document.Access, as: DocAccess
  alias Djot.Document.Traversal

  @built_in [:render, :syntax_highlight, :sanitize, :plugins, :assigns]

  @render_options_schema [
    renderer: [
      type: {:in, [:default, :minified, :indented]},
      default: :default,
      doc: "Which jotdown HTML renderer to use."
    ],
    indent_string: [
      type: :string,
      default: "\t",
      doc: "Indentation per level for the `:indented` renderer."
    ],
    indent_initial_level: [
      type: :non_neg_integer,
      default: 0,
      doc: "Starting indentation level for the `:indented` renderer."
    ]
  ]

  @syntax_highlight_options_schema [
    engine: [type: {:in, [:lumis, :syntect]}, required: true, doc: "Highlighter to use."],
    opts: [type: :keyword_list, default: [], doc: "Engine-specific options."]
  ]

  # Copied from MDEx.Document @sanitize_options_schema (MIT), with defaults
  # extended so djot's own output (sections, footnotes, task lists,
  # alignment) survives sanitizing.
  @sanitize_options_schema [
    tags: [
      type: {:list, :string},
      default:
        ~w(a abbr acronym area article aside b bdi bdo blockquote br caption center cite code col colgroup data dd del details dfn div dl dt em figcaption figure footer h1 h2 h3 h4 h5 h6 header hgroup hr i img input ins kbd li map mark nav ol p pre q rp rt rtc ruby s samp section small span strike strong sub summary sup table tbody td th thead time tr tt u ul var wbr),
      doc: "Sets the tags that are allowed."
    ],
    add_tags: [
      type: {:list, :string},
      default: [],
      doc: "Add additional whitelisted tags without overwriting old ones."
    ],
    rm_tags: [type: {:list, :string}, default: [], doc: "Remove already-whitelisted tags."],
    clean_content_tags: [
      type: {:list, :string},
      default: ~w(script style),
      doc: "Sets the tags whose contents will be completely removed from the output."
    ],
    add_clean_content_tags: [
      type: {:list, :string},
      default: [],
      doc: "Add additional blacklisted clean-content tags without overwriting old ones."
    ],
    rm_clean_content_tags: [
      type: {:list, :string},
      default: [],
      doc: "Remove already-blacklisted clean-content tags."
    ],
    tag_attributes: [
      type: {:map, :string, {:list, :string}},
      default: %{
        "a" => ~w(href hreflang id role),
        "bdo" => ~w(dir),
        "blockquote" => ~w(cite),
        "code" => ~w(class style translate tabindex),
        "div" => ~w(class style data-line),
        "col" => ~w(align char charoff span),
        "colgroup" => ~w(align char charoff span),
        "del" => ~w(cite datetime),
        "h1" => ~w(id),
        "h2" => ~w(id),
        "h3" => ~w(id),
        "h4" => ~w(id),
        "h5" => ~w(id),
        "h6" => ~w(id),
        "hr" => ~w(align size width),
        "img" => ~w(align alt height src width),
        "input" => ~w(disabled type checked),
        "ins" => ~w(cite datetime),
        "li" => ~w(id class),
        "ol" => ~w(start type),
        "pre" => ~w(class style),
        "q" => ~w(cite),
        "section" => ~w(id role),
        "span" => ~w(class style data-line),
        "table" => ~w(align char charoff summary),
        "tbody" => ~w(align char charoff),
        "td" => ~w(align char charoff colspan headers rowspan style),
        "tfoot" => ~w(align char charoff),
        "th" => ~w(align char charoff colspan headers rowspan scope style),
        "thead" => ~w(align char charoff),
        "tr" => ~w(align char charoff),
        "ul" => ~w(class)
      },
      doc: "Sets the HTML attributes that are allowed on specific tags."
    ],
    add_tag_attributes: [
      type: {:map, :string, {:list, :string}},
      default: %{},
      doc: "Add additional whitelisted tag-specific attributes without overwriting old ones."
    ],
    rm_tag_attributes: [
      type: {:map, :string, {:list, :string}},
      default: %{},
      doc: "Remove already-whitelisted tag-specific attributes."
    ],
    tag_attribute_values: [
      type: {:map, :string, {:map, :string, {:list, :string}}},
      default: %{},
      doc: "Sets the values of HTML attributes that are allowed on specific tags."
    ],
    add_tag_attribute_values: [
      type: {:map, :string, {:map, :string, {:list, :string}}},
      default: %{},
      doc:
        "Add additional whitelisted tag-specific attribute values without overwriting old ones."
    ],
    rm_tag_attribute_values: [
      type: {:map, :string, {:map, :string, {:list, :string}}},
      default: %{},
      doc: "Remove already-whitelisted tag-specific attribute values."
    ],
    set_tag_attribute_values: [
      type: {:map, :string, {:map, :string, :string}},
      default: %{},
      doc: "Sets the values of HTML attributes that are to be set on specific tags."
    ],
    set_tag_attribute_value: [
      type: {:map, :string, {:map, :string, :string}},
      default: %{},
      doc: "Add an attribute value to set on a specific element."
    ],
    rm_set_tag_attribute_value: [
      type: {:map, :string, :string},
      default: %{},
      doc: "Remove existing tag-specific attribute values to be set."
    ],
    generic_attribute_prefixes: [
      type: {:list, :string},
      default: [],
      doc: "Sets the prefix of attributes that are allowed on any tag."
    ],
    add_generic_attribute_prefixes: [
      type: {:list, :string},
      default: [],
      doc: "Add additional whitelisted attribute prefix without overwriting old ones."
    ],
    rm_generic_attribute_prefixes: [
      type: {:list, :string},
      default: [],
      doc: "Remove already-whitelisted attribute prefixes."
    ],
    generic_attributes: [
      type: {:list, :string},
      default: ~w(lang title),
      doc: "Sets the attributes that are allowed on any tag."
    ],
    add_generic_attributes: [
      type: {:list, :string},
      default: [],
      doc: "Add additional whitelisted attributes without overwriting old ones."
    ],
    rm_generic_attributes: [
      type: {:list, :string},
      default: [],
      doc: "Remove already-whitelisted attributes."
    ],
    url_schemes: [
      type: {:list, :string},
      default:
        ~w(bitcoin ftp ftps geo http https im irc ircs magnet mailto mms mx news nntp openpgp4fpr sip sms smsto ssh tel url webcal wtai xmpp),
      doc: "Sets the URL schemes permitted on href and src attributes."
    ],
    add_url_schemes: [
      type: {:list, :string},
      default: [],
      doc: "Add additional whitelisted URL schemes without overwriting old ones."
    ],
    rm_url_schemes: [
      type: {:list, :string},
      default: [],
      doc: "Remove already-whitelisted attributes."
    ],
    url_relative: [
      type:
        {:or,
         [
           {:in, [:deny, :passthrough]},
           {:tuple, [:atom, :string]},
           {:tuple, [:atom, {:tuple, [:string, :string]}]}
         ]},
      default: :passthrough,
      doc:
        "Relative URL handling: `:passthrough`, `:deny`, `{:rewrite_with_base, base}`, or `{:rewrite_with_root, {root, path}}`."
    ],
    link_rel: [
      type: {:or, [:string, nil]},
      default: "noopener noreferrer",
      doc:
        "Configures a `rel` attribute that will be added on links. Must be `nil` when `rel` is an allowed attribute."
    ],
    allowed_classes: [
      type: {:map, :string, {:list, :string}},
      default: %{},
      doc: "Sets the CSS classes that are allowed on specific tags."
    ],
    add_allowed_classes: [
      type: {:map, :string, {:list, :string}},
      default: %{},
      doc: "Add additional whitelisted classes without overwriting old ones."
    ],
    rm_allowed_classes: [
      type: {:map, :string, {:list, :string}},
      default: %{},
      doc: "Remove already-whitelisted attributes."
    ],
    strip_comments: [
      type: :boolean,
      default: true,
      doc: "Configures the handling of HTML comments."
    ],
    id_prefix: [
      type: {:or, [:string, nil]},
      default: nil,
      doc:
        "Prefixes all `id` attribute values with a given string. Note that the tag and attribute themselves must still be whitelisted."
    ]
  ]

  @options_schema [
    render: [
      type: :keyword_list,
      keys: @render_options_schema,
      default: [],
      doc: "jotdown renderer options."
    ],
    syntax_highlight: [
      type: {:or, [nil, {:keyword_list, @syntax_highlight_options_schema}]},
      default: nil,
      doc:
        "Code block highlighting, e.g. `[engine: :syntect]` or `[engine: :lumis]`. `nil` disables it."
    ],
    sanitize: [
      type: {:or, [nil, {:keyword_list, @sanitize_options_schema}]},
      default: nil,
      doc: "ammonia sanitization of the rendered HTML. `nil` disables it."
    ],
    plugins: [type: {:list, :any}, default: [], doc: "Plugins to attach."],
    assigns: [
      type: {:or, [:map, :keyword_list]},
      default: %{},
      doc: "Assigns for `Djot.to_heex/2`."
    ]
  ]

  @default_options NimbleOptions.validate!([], @options_schema) |> Keyword.delete(:plugins)
  @default_sanitize_options NimbleOptions.validate!([], @sanitize_options_schema)

  defstruct nodes: [],
            source: nil,
            options: @default_options,
            registered_options: MapSet.new(@built_in),
            steps: [],
            current_steps: [],
            halted: false,
            private: %{}

  @type step :: (t() -> t() | {t(), Exception.t()}) | {module(), atom(), [term()]}
  @type plugin :: module() | {module(), keyword()} | (t() -> t())
  @type selector :: module() | atom() | struct() | (struct() -> boolean()) | integer()

  @type t :: %__MODULE__{
          nodes: [struct()],
          source: String.t() | nil,
          options: keyword(),
          registered_options: MapSet.t(atom()),
          steps: keyword(step()),
          current_steps: [atom()],
          halted: boolean(),
          private: map()
        }

  @doc false
  def options_schema, do: @options_schema

  @doc "Default sanitize options; pass to `sanitize:` to enable sanitizing with the defaults."
  @spec default_sanitize_options() :: keyword()
  def default_sanitize_options, do: @default_sanitize_options

  @doc false
  def sanitize_options_schema, do: @sanitize_options_schema

  @doc false
  def syntax_highlight_options_schema, do: @syntax_highlight_options_schema

  @doc "Registers user option keys so `put_options/2` accepts them."
  @spec register_options(t(), [atom()]) :: t()
  def register_options(%__MODULE__{} = doc, options) when is_list(options) do
    %{doc | registered_options: MapSet.union(doc.registered_options, MapSet.new(options))}
  end

  @doc """
  Merges options into the document. `:plugins` are attached first, then the
  remaining keys are applied in order.

  Raises `ArgumentError` for keys that are neither built-in nor registered.
  """
  @spec put_options(t(), keyword()) :: t()
  def put_options(%__MODULE__{} = doc, options) when is_list(options) do
    {plugins, rest} = Keyword.pop_values(options, :plugins)
    doc = Enum.reduce(plugins, doc, &put_plugins(&2, &1))
    Enum.reduce(rest, doc, fn {key, value}, acc -> put_option(acc, key, value) end)
  end

  defp put_option(doc, :render, value) do
    merged = Keyword.merge(get_option(doc, :render, []), value)
    put_raw(doc, :render, NimbleOptions.validate!(merged, @render_options_schema))
  end

  defp put_option(doc, :sanitize, nil), do: put_raw(doc, :sanitize, nil)

  defp put_option(doc, :sanitize, value) when is_list(value) do
    merged = Keyword.merge(get_option(doc, :sanitize) || [], value)
    put_raw(doc, :sanitize, NimbleOptions.validate!(merged, @sanitize_options_schema))
  end

  defp put_option(doc, :syntax_highlight, nil), do: put_raw(doc, :syntax_highlight, nil)

  defp put_option(doc, :syntax_highlight, value) when is_list(value) do
    current = get_option(doc, :syntax_highlight) || []
    opts = Keyword.merge(Keyword.get(current, :opts, []), Keyword.get(value, :opts, []))
    merged = current |> Keyword.merge(value) |> Keyword.put(:opts, opts)

    put_raw(
      doc,
      :syntax_highlight,
      NimbleOptions.validate!(merged, @syntax_highlight_options_schema)
    )
  end

  defp put_option(doc, :assigns, value) when is_map(value) or is_list(value) do
    put_raw(doc, :assigns, Map.merge(get_option(doc, :assigns, %{}), Map.new(value)))
  end

  defp put_option(_doc, key, value) when key in [:sanitize, :syntax_highlight, :assigns] do
    raise ArgumentError, "invalid value for option #{inspect(key)}: #{inspect(value)}"
  end

  defp put_option(doc, key, value) do
    if MapSet.member?(doc.registered_options, key) do
      put_raw(doc, key, value)
    else
      raise ArgumentError, "unknown option #{inspect(key)}"
    end
  end

  defp put_raw(doc, key, value), do: %{doc | options: Keyword.put(doc.options, key, value)}

  @doc "Merges `:render` options."
  @spec put_render_options(t(), keyword()) :: t()
  def put_render_options(doc, options), do: put_options(doc, render: options)

  @doc "Merges `:syntax_highlight` options; `nil` disables highlighting."
  @spec put_syntax_highlight_options(t(), keyword() | nil) :: t()
  def put_syntax_highlight_options(doc, options), do: put_options(doc, syntax_highlight: options)

  @doc "Merges `:sanitize` options; `nil` disables sanitizing."
  @spec put_sanitize_options(t(), keyword() | nil) :: t()
  def put_sanitize_options(doc, options), do: put_options(doc, sanitize: options)

  @doc """
  Attaches plugins: `module` calls `module.attach(doc, [])`, `{module, opts}`
  calls `module.attach(doc, opts)`, and a 1-arity function is called with the doc.
  """
  @spec put_plugins(t(), [plugin()]) :: t()
  def put_plugins(%__MODULE__{} = doc, plugins) when is_list(plugins) do
    Enum.reduce(plugins, doc, fn
      fun, acc when is_function(fun, 1) -> fun.(acc)
      {module, opts}, acc when is_atom(module) and is_list(opts) -> module.attach(acc, opts)
      module, acc when is_atom(module) -> module.attach(acc, [])
      other, _ -> raise ArgumentError, "invalid plugin: #{inspect(other)}"
    end)
  end

  @doc "Returns an option value."
  @spec get_option(t(), atom(), term()) :: term()
  def get_option(%__MODULE__{} = doc, key, default \\ nil) when is_atom(key) do
    Keyword.get(doc.options, key, default)
  end

  @doc "Adds one assign."
  @spec assign(t(), atom(), term()) :: t()
  def assign(%__MODULE__{} = doc, key, value) when is_atom(key),
    do: put_options(doc, assigns: %{key => value})

  @doc "Merges assigns from a map or keyword list."
  @spec assign(t(), map() | keyword()) :: t()
  def assign(%__MODULE__{} = doc, assigns) when is_map(assigns) or is_list(assigns),
    do: put_options(doc, assigns: assigns)

  @doc "Appends named steps to the pipeline."
  @spec append_steps(t(), keyword(step())) :: t()
  def append_steps(%__MODULE__{} = doc, steps) do
    %{doc | steps: doc.steps ++ steps, current_steps: doc.current_steps ++ Keyword.keys(steps)}
  end

  @doc "Prepends named steps to the pipeline."
  @spec prepend_steps(t(), keyword(step())) :: t()
  def prepend_steps(%__MODULE__{} = doc, steps) do
    %{doc | steps: steps ++ doc.steps, current_steps: Keyword.keys(steps) ++ doc.current_steps}
  end

  @doc "Stops the pipeline; no further steps run. The document still renders."
  @spec halt(t()) :: t()
  def halt(%__MODULE__{} = doc), do: %{doc | halted: true}

  @doc "Stops the pipeline with an exception; rendering returns `{:error, exception}`."
  @spec halt(t(), Exception.t()) :: {t(), Exception.t()}
  def halt(%__MODULE__{} = doc, %_{__exception__: true} = exception),
    do: {%{doc | halted: true}, exception}

  @doc "Stores private (plugin-internal) data."
  @spec put_private(t(), atom(), term()) :: t()
  def put_private(%__MODULE__{} = doc, key, value) when is_atom(key),
    do: %{doc | private: Map.put(doc.private, key, value)}

  @doc "Reads private data."
  @spec get_private(t(), atom(), term()) :: term()
  def get_private(%__MODULE__{} = doc, key, default \\ nil) when is_atom(key),
    do: Map.get(doc.private, key, default)

  @doc "Updates private data with `fun`, starting from `default`."
  @spec update_private(t(), atom(), term(), (term() -> term())) :: t()
  def update_private(%__MODULE__{} = doc, key, default, fun)
      when is_atom(key) and is_function(fun, 1),
      do: %{doc | private: Map.update(doc.private, key, default, fun)}

  @doc "Sets Djot source to be parsed by `run/1`."
  @spec put_source(t(), String.t() | nil) :: t()
  def put_source(%__MODULE__{} = doc, source) when is_binary(source) or is_nil(source),
    do: %{doc | source: source}

  @doc """
  Runs the pipeline: parses pending `source` (appending to `nodes`), then runs
  the pending steps in order until one halts.
  """
  @spec run(t()) :: t() | {t(), Exception.t()}
  def run(%__MODULE__{} = doc) do
    doc =
      if is_binary(doc.source) do
        %{doc | nodes: doc.nodes ++ Djot.Native.parse(doc.source), source: nil}
      else
        doc
      end

    do_run(doc)
  end

  defp do_run(%__MODULE__{current_steps: []} = doc), do: doc

  defp do_run(%__MODULE__{current_steps: [name | rest]} = doc) do
    case run_step(Keyword.fetch!(doc.steps, name), doc) do
      {%__MODULE__{} = doc, exception} -> {%{doc | current_steps: []}, exception}
      %__MODULE__{halted: true} = doc -> %{doc | current_steps: []}
      %__MODULE__{} = doc -> do_run(%{doc | current_steps: rest})
    end
  end

  defp run_step(step, doc) when is_function(step, 1), do: step.(doc)

  defp run_step({m, f, a}, doc) when is_atom(m) and is_atom(f) and is_list(a),
    do: apply(m, f, [doc | a])

  @doc "Applies `fun` to every node matching `selector` (post-order)."
  @spec update_nodes(t(), selector(), (struct() -> struct())) :: t()
  def update_nodes(%__MODULE__{} = doc, selector, fun) when is_function(fun, 1) do
    match? = DocAccess.matcher(selector)

    Traversal.traverse_and_update(doc, fn node -> if match?.(node), do: fun.(node), else: node end)
  end

  @doc "Wraps a node or a list of nodes in a document."
  @spec wrap(struct() | [struct()]) :: t()
  def wrap(node_or_nodes), do: %__MODULE__{nodes: Elixir.List.wrap(node_or_nodes)}

  @doc "Inserts `node` at the `:top` (default) or `:bottom` of the document root."
  @spec put_node_in_document_root(t(), struct(), :top | :bottom) :: t()
  def put_node_in_document_root(doc, node, position \\ :top)

  def put_node_in_document_root(%__MODULE__{} = doc, node, :top),
    do: %{doc | nodes: [node | doc.nodes]}

  def put_node_in_document_root(%__MODULE__{} = doc, node, :bottom),
    do: %{doc | nodes: doc.nodes ++ [node]}
end
