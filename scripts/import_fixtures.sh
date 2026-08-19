#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$root"

# Developer-side fixture importer. The committed fixtures are stable, so tests never
# need this script, a SQLite DB, or ffmpeg at runtime.
# Set FIXTURE_OGG_DB to a SQLite database with an audio_versions(audio_data) table.
if [ -z "${FIXTURE_OGG_DB:-}" ]; then
  echo "set FIXTURE_OGG_DB to a SQLite path with Ogg Opus blobs" >&2
  exit 1
fi
db=$FIXTURE_OGG_DB
fixture_dir=test/fixtures
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

if [ ! -f "$db" ]; then
  echo "fixture DB not found at $db (set FIXTURE_OGG_DB)" >&2
  exit 1
fi

command -v sqlite3 >/dev/null || { echo "sqlite3 required" >&2; exit 1; }
command -v ffmpeg >/dev/null || { echo "ffmpeg required" >&2; exit 1; }

mkdir -p "$fixture_dir"

extract_ogg() {
  # $1: row id, $2: destination file
  sqlite3 "$db" "SELECT writefile('$2', audio_data) FROM audio_versions WHERE id = '$1';" >/dev/null
  test -s "$2"
}

# Two representative clips from the audio_versions table.
id1=$(sqlite3 "$db" "SELECT id FROM audio_versions WHERE byte_size BETWEEN 60000 AND 100000 ORDER BY byte_size LIMIT 1;")
id2=$(sqlite3 "$db" "SELECT id FROM audio_versions WHERE byte_size BETWEEN 60000 AND 100000 ORDER BY byte_size DESC LIMIT 1;")
test -n "$id1" && test -n "$id2"

extract_ogg "$id1" "$tmpdir/clip1.ogg"
extract_ogg "$id2" "$tmpdir/clip2.ogg"

# Decode to the stable PCM contract (f32 little-endian).
ffmpeg -y -i "$tmpdir/clip1.ogg" -ac 1 -ar 16000 -t 1.2 -f f32le -acodec pcm_f32le \
  "$fixture_dir/speech_16k_mono.f32" >/dev/null 2>&1
ffmpeg -y -i "$tmpdir/clip2.ogg" -ac 2 -ar 16000 -t 0.8 -f f32le -acodec pcm_f32le \
  "$fixture_dir/speech_16k_stereo.f32" >/dev/null 2>&1

# Golden Opus packet: encode the first 20ms frame of the mono fixture with the
# library itself (a deterministic committed regression fixture for the decoder).
RUSTY_OPUS_BUILD=1 MIX_ENV=test mix run -e '
  alias RustyOpus.Encoder
  pcm = File.read!("test/fixtures/speech_16k_mono.f32")
  # a loud speech-rich 20 ms frame ~0.06s into the clip
  frame = binary_part(pcm, 3_840, 320 * 4)
  {:ok, encoder} = Encoder.new(16_000, 1, :voip, bitrate: 24_000)
  {:ok, packet} = Encoder.encode(encoder, frame, 320)
  File.write!("test/fixtures/golden_16k_mono.opus", packet)
' >/dev/null

echo "imported fixtures:"
ls -la "$fixture_dir"
