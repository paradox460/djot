defmodule Djot.Native do
  use Rustler, otp_app: :djot, crate: :djot_nif

  def to_html(_dj), do: :erlang.nif_error(:nif_not_loaded)
end
