#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)

if [ "$#" -ne 1 ]; then
  echo "usage: $0 OUTPUT_DIRECTORY" >&2
  exit 64
fi

output=$1
command -v ffmpeg >/dev/null 2>&1 || { echo "ffmpeg is required" >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "python3 is required" >&2; exit 1; }

mono="$root/test/fixtures/speech_16k_mono.f32"
stereo="$root/test/fixtures/speech_16k_stereo.f32"
test -f "$mono" && test -f "$stereo"
mkdir -p "$output"

ffmpeg_run() {
  ffmpeg -nostdin -hide_banner -loglevel error -y "$@"
}

# Independently encoded valid files. No runtime or test-under-test invokes this tool.
ffmpeg_run -f f32le -ar 16000 -ac 1 -i "$mono" \
  -map_metadata -1 -c:a pcm_s16le "$output/wav_s16_16k_mono.wav"
ffmpeg_run -f f32le -ar 16000 -ac 2 -i "$stereo" -ar 48000 \
  -map_metadata -1 -c:a pcm_s24le "$output/wav_s24_48k_stereo.wav"
ffmpeg_run -f f32le -ar 16000 -ac 2 -i "$stereo" -ar 44100 \
  -map_metadata -1 -c:a pcm_f32le "$output/wav_f32_44k_stereo.wav"

ffmpeg_run -f f32le -ar 16000 -ac 2 -i "$stereo" -ar 44100 \
  -map_metadata -1 -c:a libmp3lame -b:a 64k -write_xing 1 -id3v2_version 0 \
  "$output/mp3_mpeg1_44k_stereo_cbr64.mp3"
ffmpeg_run -f f32le -ar 16000 -ac 2 -i "$stereo" -ar 44100 \
  -c:a libmp3lame -q:a 6 -write_xing 1 -id3v2_version 3 \
  -metadata title=ROADMAP004-fixture "$output/mp3_mpeg1_44k_stereo_vbr_id3.mp3"
ffmpeg_run -f f32le -ar 16000 -ac 1 -i "$mono" -ar 22050 \
  -map_metadata -1 -c:a libmp3lame -b:a 32k -write_xing 1 -id3v2_version 0 \
  "$output/mp3_mpeg2_22k_mono_cbr32.mp3"
ffmpeg_run -f f32le -ar 16000 -ac 1 -i "$mono" -ar 11025 \
  -map_metadata -1 -c:a libmp3lame -b:a 24k -write_xing 1 -id3v2_version 0 \
  "$output/mp3_mpeg25_11k_mono_cbr24.mp3"

ffmpeg_run -f f32le -ar 16000 -ac 2 -i "$stereo" -ar 48000 \
  -map_metadata -1 -c:a libopus -application audio -b:a 64k \
  "$output/ogg_opus_48k_stereo.ogg"

# Small, targeted invalid inputs. They are deterministic and require no random source.
python3 - "$output" <<'PY'
import pathlib, struct, sys

out = pathlib.Path(sys.argv[1])

# FFmpeg chooses a random Ogg stream serial. Canonicalize it and every page CRC so
# repeated imports produce identical committed bytes.
def ogg_crc(page):
    value = 0
    for byte in page:
        value ^= byte << 24
        for _ in range(8):
            value = ((value << 1) ^ (0x04C11DB7 if value & 0x80000000 else 0)) & 0xffffffff
    return value

ogg_path = out / "ogg_opus_48k_stereo.ogg"
ogg = bytearray(ogg_path.read_bytes())
pos = 0
while pos < len(ogg):
    if ogg[pos:pos + 4] != b"OggS" or pos + 27 > len(ogg):
        raise SystemExit("generated Ogg fixture has an invalid page")
    segments = ogg[pos + 26]
    header_len = 27 + segments
    if pos + header_len > len(ogg):
        raise SystemExit("generated Ogg fixture has a truncated lacing table")
    body_len = sum(ogg[pos + 27:pos + header_len])
    page_end = pos + header_len + body_len
    if page_end > len(ogg):
        raise SystemExit("generated Ogg fixture has a truncated body")
    ogg[pos + 14:pos + 18] = struct.pack("<I", 0x524F3034)
    ogg[pos + 22:pos + 26] = b"\x00\x00\x00\x00"
    ogg[pos + 22:pos + 26] = struct.pack("<I", ogg_crc(ogg[pos:page_end]))
    pos = page_end
ogg_path.write_bytes(ogg)

(out / "corrupt_mp3_truncated_id3.mp3").write_bytes(
    b"ID3\x04\x00\x00\x00\x00\x01\x00" + b"short"
)
(out / "corrupt_mp3_bad_sync.mp3").write_bytes(b"\xff\xfb\x90\x64" + bytes(19))
(out / "corrupt_wav_oversized_chunk.wav").write_bytes(
    b"RIFF" + struct.pack("<I", 20) + b"WAVEfmt " + struct.pack("<I", 0xfffffff0)
)
(out / "unsupported_wav_mulaw.wav").write_bytes(
    b"RIFF" + struct.pack("<I", 37) + b"WAVEfmt " + struct.pack("<IHHIIHH", 16, 7, 1, 8000, 8000, 1, 8)
    + b"data" + struct.pack("<I", 1) + b"\x7f" + b"\x00"
)
ogg = bytearray(ogg_path.read_bytes())
if len(ogg) < 27:
    raise SystemExit("generated Ogg fixture is unexpectedly short")
ogg[22] ^= 0x01
(out / "corrupt_ogg_bad_crc.ogg").write_bytes(ogg[: min(len(ogg), 256)])
PY

printf 'generated ROADMAP004 fixtures in %s\n' "$output"
ffmpeg -version | head -n 1
find "$output" -type f -maxdepth 1 -print | sort
