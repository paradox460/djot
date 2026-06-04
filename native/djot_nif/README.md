# Djot NIF (Rustler Precompiled)

This crate implements the native implementation for the `Djot` library via a Rust
NIF compiled with Rustler‑Precompiled. It is loaded in Elixir through the module
`Djot.Native`:

```elixir
defmodule Djot.Native do
  use RustlerPrecompiled,
    otp_app: :djot,
    crate: "djot_nif"
end
```

The only public NIF function is `to_html/2`, which takes a Djot markup string and
an options struct (`Djot.Options` in Elixir) and returns either `{:ok, html}` or
`{:error, :djot_transform}` on failure.

Building the NIF is handled automatically by `mix compile`; in development and
test environments the crate will be built from source, while in production a
pre‑compiled binary is downloaded from the GitHub releases.

Refer to the top‑level `README.md` for usage examples.
