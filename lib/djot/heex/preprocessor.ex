defmodule Djot.HEEx.Preprocessor do
  @moduledoc false
  # Rewrites HEEx constructs (tags, `{expr}`, `<% %>`) in djot source into
  # djot raw `heex` syntax so the parser passes them through untouched.
  # Fenced code, inline verbatim, and backslash escapes are copied verbatim.

  @tag_start ~r/\A<\/?(?:\.[a-z_]|:[a-z_]|[A-Z]\w*(?:\.[A-Z]\w*)*\.[a-z_])/
  @attr_start ~r/\A\{[A-Za-z_][\w:-]*=/
  @not_expr ~c".#%_*=+-^~}'\" \t\r\n"

  @spec rewrite(String.t()) :: String.t()
  def rewrite(source) when is_binary(source), do: scan(source, "", {:ws, ""})

  # `line` is {:ws, indent} while only whitespace has been seen on the current
  # line, :text afterwards.
  defp scan("", out, _line), do: out

  defp scan("\n" <> rest, out, _line), do: scan(rest, out <> "\n", {:ws, ""})

  defp scan(<<c, rest::binary>>, out, {:ws, indent}) when c in [?\s, ?\t] do
    scan(rest, <<out::binary, c>>, {:ws, <<indent::binary, c>>})
  end

  defp scan(<<c, _::binary>> = src, out, {:ws, _} = line) when c in [?`, ?~] do
    n = run_length(src, c)

    if n >= 3 do
      {fence, rest} = take_fence(src, c, n)
      scan(rest, out <> fence, {:ws, ""})
    else
      inline(src, out, line)
    end
  end

  defp scan(src, out, line), do: inline(src, out, line)

  defp inline("\\" <> <<c::utf8, rest::binary>>, out, _line),
    do: scan(rest, out <> "\\" <> <<c::utf8>>, :text)

  defp inline("\\", out, _line), do: out <> "\\"

  defp inline("`" <> _ = src, out, _line) do
    n = run_length(src, ?`)
    {verbatim, rest} = take_verbatim(src, n)
    scan(rest, out <> verbatim, :text)
  end

  defp inline("<%" <> _ = src, out, line) do
    case :binary.match(src, "%>") do
      {pos, 2} -> construct(src, pos + 2, out, line)
      :nomatch -> literal(src, out)
    end
  end

  defp inline("<" <> _ = src, out, line) do
    with true <- Regex.match?(@tag_start, src),
         {:ok, len} <- tag_end(src, 1, 0) do
      construct(src, len, out, line)
    else
      _ -> literal(src, out)
    end
  end

  defp inline("{" <> rest = src, out, line) do
    with <<next, _::binary>> when next not in @not_expr <- rest,
         false <- Regex.match?(@attr_start, src),
         {:ok, len} <- brace_end(src, 1, 0) do
      construct(src, len, out, line)
    else
      _ -> literal(src, out)
    end
  end

  defp inline(src, out, _line), do: literal(src, out)

  defp literal(<<c::utf8, rest::binary>>, out), do: scan(rest, <<out::binary, c::utf8>>, :text)
  # Invalid UTF-8 byte: copy as-is.
  defp literal(<<c, rest::binary>>, out), do: scan(rest, <<out::binary, c>>, :text)

  defp construct(src, len, out, line) do
    <<code::binary-size(^len), rest::binary>> = src

    case {line, block_tail(rest)} do
      {{:ws, indent}, {:ok, rest}} ->
        out = binary_part(out, 0, byte_size(out) - byte_size(indent))
        out = if out == "" or String.ends_with?(out, "\n\n"), do: out, else: out <> "\n"
        fence = String.duplicate("`", max(3, longest_backticks(code) + 1))
        out = out <> indent <> fence <> "=heex\n" <> code <> "\n" <> indent <> fence <> "\n\n"
        scan(rest, out, {:ws, ""})

      _ ->
        ticks = String.duplicate("`", longest_backticks(code) + 1)
        pad = if String.starts_with?(code, "`") or String.ends_with?(code, "`"), do: " ", else: ""
        scan(rest, out <> ticks <> pad <> code <> pad <> ticks <> "{=heex}", :text)
    end
  end

  # Only whitespace up to the newline (consumed) or EOF.
  defp block_tail(<<c, rest::binary>>) when c in [?\s, ?\t, ?\r], do: block_tail(rest)
  defp block_tail("\n" <> rest), do: {:ok, rest}
  defp block_tail(""), do: {:ok, ""}
  defp block_tail(_), do: :error

  defp longest_backticks(code) do
    ~r/`+/
    |> Regex.scan(code)
    |> Enum.map(fn [run] -> byte_size(run) end)
    |> Enum.max(fn -> 0 end)
  end

  defp run_length(<<c, rest::binary>>, c), do: 1 + run_length(rest, c)
  defp run_length(_, _), do: 0

  # Copies a fenced block through its closing fence line (or EOF).
  defp take_fence(src, c, n) do
    {first, rest} = split_line(src)
    take_fence_body(rest, c, n, first)
  end

  defp take_fence_body("", _c, _n, acc), do: {acc, ""}

  defp take_fence_body(src, c, n, acc) do
    {line, rest} = split_line(src)
    trimmed = String.trim_leading(line, " ")
    m = run_length(trimmed, c)
    <<_::binary-size(^m), tail::binary>> = trimmed

    if m >= n and String.trim(tail) == "" do
      {acc <> line, rest}
    else
      take_fence_body(rest, c, n, acc <> line)
    end
  end

  # Returns {line_including_newline, rest}.
  defp split_line(src) do
    case :binary.match(src, "\n") do
      {pos, 1} ->
        {binary_part(src, 0, pos + 1), binary_part(src, pos + 1, byte_size(src) - pos - 1)}

      :nomatch ->
        {src, ""}
    end
  end

  # Inline verbatim: a run of n backticks through the next run of exactly n,
  # not crossing a blank line. Unclosed: only the opening run is literal.
  defp take_verbatim(src, n) do
    <<open::binary-size(^n), body::binary>> = src

    case close_verbatim(body, n, 0) do
      {:ok, len} ->
        <<content::binary-size(^len), rest::binary>> = body
        {open <> content, rest}

      :error ->
        {open, body}
    end
  end

  defp close_verbatim("", _n, _pos), do: :error

  defp close_verbatim("`" <> _ = src, n, pos) do
    m = run_length(src, ?`)

    if m == n do
      {:ok, pos + m}
    else
      <<_::binary-size(^m), rest::binary>> = src
      close_verbatim(rest, n, pos + m)
    end
  end

  defp close_verbatim("\n" <> rest, n, pos) do
    if blank_line?(rest), do: :error, else: close_verbatim(rest, n, pos + 1)
  end

  defp close_verbatim(<<_, rest::binary>>, n, pos), do: close_verbatim(rest, n, pos + 1)

  defp blank_line?(<<c, rest::binary>>) when c in [?\s, ?\t, ?\r], do: blank_line?(rest)
  defp blank_line?("\n" <> _), do: true
  defp blank_line?(_), do: false

  # Length through the first `>` outside quotes and balanced braces.
  defp tag_end(src, pos, depth) when pos < byte_size(src) do
    case :binary.at(src, pos) do
      ?> when depth == 0 ->
        {:ok, pos + 1}

      q when q in [?", ?'] ->
        with {:ok, pos} <- quote_end(src, pos + 1, q), do: tag_end(src, pos, depth)

      ?{ ->
        tag_end(src, pos + 1, depth + 1)

      ?} when depth > 0 ->
        tag_end(src, pos + 1, depth - 1)

      _ ->
        tag_end(src, pos + 1, depth)
    end
  end

  defp tag_end(_src, _pos, _depth), do: :error

  # Length through the `}` matching the opening `{` at 0.
  defp brace_end(src, pos, depth) when pos < byte_size(src) do
    case :binary.at(src, pos) do
      ?} when depth == 0 ->
        {:ok, pos + 1}

      ?} ->
        brace_end(src, pos + 1, depth - 1)

      ?{ ->
        brace_end(src, pos + 1, depth + 1)

      q when q in [?", ?'] ->
        with {:ok, pos} <- quote_end(src, pos + 1, q), do: brace_end(src, pos, depth)

      _ ->
        brace_end(src, pos + 1, depth)
    end
  end

  defp brace_end(_src, _pos, _depth), do: :error

  # Position just past the closing quote `q`, honoring backslash escapes.
  defp quote_end(src, pos, q) when pos < byte_size(src) do
    case :binary.at(src, pos) do
      ?\\ -> quote_end(src, pos + 2, q)
      ^q -> {:ok, pos + 1}
      _ -> quote_end(src, pos + 1, q)
    end
  end

  defp quote_end(_src, _pos, _q), do: :error
end
