# Smoke-load a raw precompiled RustyOpus NIF without Mix/Rustler compile.
#
# Env:
#   NIF_PATH — path to the extracted .so / .dylib
#   PROJECT_VERSION — expected CARGO_PKG_VERSION from native_smoke

nif_input = System.fetch_env!("NIF_PATH")
project_version = System.fetch_env!("PROJECT_VERSION")

nif_file = Path.expand(nif_input)
extension = Path.extname(nif_file)

unless extension in [".so", ".dylib"] do
  raise "NIF_PATH must name a .so or .dylib library"
end

unless File.regular?(nif_file), do: raise("NIF library does not exist: #{nif_file}")

# Erlang's loader appends .so; copy dylib to a temp .so when needed.
runtime_extension = ".so"

load_file =
  if extension == runtime_extension do
    nif_file
  else
    copied =
      Path.join(
        System.tmp_dir!(),
        "rusty_opus_raw_smoke_#{System.unique_integer([:positive, :monotonic])}#{runtime_extension}"
      )

    File.cp!(nif_file, copied)
    copied
  end

load_path = String.trim_trailing(load_file, runtime_extension)

{:module, RustyOpus.Native, _binary, _term} =
  Module.create(
    RustyOpus.Native,
    quote do
      @on_load :__load_nif__
      def __load_nif__, do: :erlang.load_nif(unquote(String.to_charlist(load_path)), 0)

      def smoke, do: :erlang.nif_error(:nif_not_loaded)
      def translated_error, do: :erlang.nif_error(:nif_not_loaded)
      def contained_panic, do: :erlang.nif_error(:nif_not_loaded)

      def encoder_new(_rate, _channels, _application, _settings),
        do: :erlang.nif_error(:nif_not_loaded)

      def encoder_encode(_resource, _pcm, _frame_size), do: :erlang.nif_error(:nif_not_loaded)
      def encoder_encode_many(_resource, _pcm, _frame_size), do: :erlang.nif_error(:nif_not_loaded)
      def encoder_set(_resource, _settings), do: :erlang.nif_error(:nif_not_loaded)
      def encoder_close(_resource), do: :erlang.nif_error(:nif_not_loaded)
      def encoder_count, do: :erlang.nif_error(:nif_not_loaded)

      def decoder_new(_rate, _channels), do: :erlang.nif_error(:nif_not_loaded)
      def decoder_decode(_resource, _packet, _frame_size), do: :erlang.nif_error(:nif_not_loaded)

      def decoder_decode_many(_resource, _packets, _frame_size),
        do: :erlang.nif_error(:nif_not_loaded)

      def decoder_close(_resource), do: :erlang.nif_error(:nif_not_loaded)
      def decoder_count, do: :erlang.nif_error(:nif_not_loaded)

      def wav_decode(_blob), do: :erlang.nif_error(:nif_not_loaded)
      def wav_encode(_pcm, _rate, _channels, _format), do: :erlang.nif_error(:nif_not_loaded)
      def mp3_decode(_blob), do: :erlang.nif_error(:nif_not_loaded)
      def mp3_encode(_pcm, _rate, _channels, _settings), do: :erlang.nif_error(:nif_not_loaded)
      def ogg_decode(_blob), do: :erlang.nif_error(:nif_not_loaded)
      def ogg_encode(_pcm, _channels, _settings), do: :erlang.nif_error(:nif_not_loaded)
      def ogg_reencode(_blob, _settings), do: :erlang.nif_error(:nif_not_loaded)
    end,
    Macro.Env.location(__ENV__)
  )

{:ok, ^project_version} = RustyOpus.Native.smoke()
IO.puts("Raw precompiled NIF smoke passed: #{nif_file}")
