defmodule Djot.Options do
  @moduledoc """
  Configurable options for the Djot renderer

  + `renderer`: Which djot renderer you want to use, `default`, `indented`, or `minified`
  + `indent_string`: The string used for each indentation level when using the `indented` renderer
  + `indent_initial_level`: What level to start the indentation at
  """

  defstruct renderer: :default,
            indent_string: "\t",
            indent_initial_level: 0

  @type renderer :: :default | :indented | :minified
  @type t :: %__MODULE__{
          renderer: renderer(),
          indent_string: String.t(),
          indent_initial_level: integer()
        }
end
