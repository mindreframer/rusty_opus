//! Small, in-memory RIFF/WAVE reader and writer.
#![allow(clippy::all)]

const MAX_BYTES: usize = 256 * 1024 * 1024;

fn err(reason: &str, message: impl Into<String>) -> (String, String) {
    (reason.to_string(), message.into())
}

fn u16le(bytes: &[u8]) -> u16 {
    u16::from_le_bytes([bytes[0], bytes[1]])
}

fn u32le(bytes: &[u8]) -> u32 {
    u32::from_le_bytes([bytes[0], bytes[1], bytes[2], bytes[3]])
}

fn check_range(pos: usize, len: usize, end: usize) -> Result<(), (String, String)> {
    pos.checked_add(len)
        .filter(|&next| next <= end)
        .map(|_| ())
        .ok_or_else(|| {
            err(
                "decode_failed",
                "WAV chunk exceeds the declared RIFF boundary",
            )
        })
}

struct WavInfo<'a> {
    channels: usize,
    rate: u32,
    bits: u16,
    float: bool,
    data: &'a [u8],
}

fn parse(bytes: &[u8]) -> Result<WavInfo<'_>, (String, String)> {
    if bytes.len() < 12 {
        return Err(err("invalid_input", "WAV header is truncated"));
    }
    if &bytes[0..4] != b"RIFF" || &bytes[8..12] != b"WAVE" {
        return Err(err("invalid_input", "input is not a RIFF/WAVE file"));
    }
    let riff_size = u32le(&bytes[4..8]) as usize;
    let riff_end = 8usize
        .checked_add(riff_size)
        .ok_or_else(|| err("allocation_bound", "WAV RIFF size overflows"))?;
    if riff_end > bytes.len() || riff_end < 12 {
        return Err(err("decode_failed", "WAV RIFF size exceeds the input"));
    }
    if riff_end != bytes.len() {
        return Err(err(
            "decode_failed",
            "WAV contains bytes outside its RIFF boundary",
        ));
    }

    let mut pos = 12usize;
    let mut fmt: Option<(usize, u32, u16, u16, bool)> = None;
    let mut data: Option<&[u8]> = None;
    while pos < riff_end {
        check_range(pos, 8, riff_end)?;
        let id = &bytes[pos..pos + 4];
        let chunk_size = u32le(&bytes[pos + 4..pos + 8]) as usize;
        let content = pos + 8;
        check_range(content, chunk_size, riff_end)?;
        if id == b"fmt " {
            if fmt.is_some() || chunk_size < 16 {
                return Err(err(
                    "decode_failed",
                    "WAV has a duplicate or malformed fmt chunk",
                ));
            }
            let f = &bytes[content..content + chunk_size];
            let tag = u16le(&f[0..2]);
            let channels = u16le(&f[2..4]);
            let rate = u32le(&f[4..8]);
            let block_align = u16le(&f[12..14]);
            let bits = u16le(&f[14..16]);
            let (tag, bits) = if tag == 0xfffe {
                if chunk_size < 40 {
                    return Err(err(
                        "decode_failed",
                        "WAVE_FORMAT_EXTENSIBLE fmt chunk is truncated",
                    ));
                }
                let valid_bits = u16le(&f[18..20]);
                if valid_bits == 0 || valid_bits > bits {
                    return Err(err(
                        "decode_failed",
                        "invalid extensible WAV valid-bit count",
                    ));
                }
                let subformat = &f[24..40];
                const PCM_GUID: [u8; 16] =
                    [1, 0, 0, 0, 0, 0, 16, 0, 128, 0, 0, 170, 0, 56, 155, 113];
                const FLOAT_GUID: [u8; 16] =
                    [3, 0, 0, 0, 0, 0, 16, 0, 128, 0, 0, 170, 0, 56, 155, 113];
                if subformat == PCM_GUID {
                    (1, bits)
                } else if subformat == FLOAT_GUID {
                    (3, bits)
                } else {
                    return Err(err("invalid_input", "unsupported extensible WAV subtype"));
                }
            } else {
                (tag, bits)
            };
            if channels == 0 || channels > 2 || rate == 0 {
                return Err(err(
                    "invalid_input",
                    "WAV must contain one or two channels and a positive rate",
                ));
            }
            let expected = usize::from(channels)
                .checked_mul(usize::from(bits / 8))
                .ok_or_else(|| err("decode_failed", "WAV block alignment overflows"))?;
            if bits % 8 != 0 || block_align as usize != expected {
                return Err(err("decode_failed", "WAV block alignment is inconsistent"));
            }
            let float = tag == 3;
            if tag != 1 && tag != 3
                || (float && bits != 32)
                || (!float && !matches!(bits, 8 | 16 | 24 | 32))
            {
                return Err(err("invalid_input", "unsupported WAV sample format"));
            }
            fmt = Some((usize::from(channels), rate, bits, block_align, float));
        } else if id == b"data" {
            if data.is_some() {
                return Err(err("decode_failed", "WAV has duplicate data chunks"));
            }
            data = Some(&bytes[content..content + chunk_size]);
        }
        let padded = chunk_size
            .checked_add(chunk_size & 1)
            .ok_or_else(|| err("decode_failed", "WAV chunk padding overflows"))?;
        check_range(content, padded, riff_end)?;
        pos = content
            .checked_add(padded)
            .ok_or_else(|| err("decode_failed", "WAV chunk position overflows"))?;
    }
    let (channels, rate, bits, block_align, float) =
        fmt.ok_or_else(|| err("decode_failed", "WAV is missing a fmt chunk"))?;
    let data = data.ok_or_else(|| err("decode_failed", "WAV is missing a data chunk"))?;
    if data.len() % usize::from(block_align) != 0 {
        return Err(err(
            "decode_failed",
            "WAV data is not aligned to complete frames",
        ));
    }
    if data.len() > MAX_BYTES {
        return Err(err(
            "allocation_bound",
            "WAV data exceeds the maximum supported size",
        ));
    }
    Ok(WavInfo {
        channels,
        rate,
        bits,
        float,
        data,
    })
}

fn finite(value: f32) -> bool {
    value.is_finite()
}

pub fn decode(bytes: &[u8]) -> Result<(u32, usize, Vec<u8>), (String, String)> {
    let info = parse(bytes)?;
    let samples = info.data.len() / (usize::from(info.bits / 8));
    let out_len = samples
        .checked_mul(4)
        .ok_or_else(|| err("allocation_bound", "decoded WAV PCM size overflows"))?;
    if out_len > MAX_BYTES {
        return Err(err(
            "allocation_bound",
            "decoded WAV PCM exceeds the maximum supported size",
        ));
    }
    let mut out = Vec::with_capacity(out_len);
    for chunk in info.data.chunks_exact(usize::from(info.bits / 8)) {
        let value = if info.float {
            f32::from_le_bytes([chunk[0], chunk[1], chunk[2], chunk[3]])
        } else {
            match info.bits {
                8 => (f32::from(chunk[0]) - 128.0) / 128.0,
                16 => i16::from_le_bytes([chunk[0], chunk[1]]) as f32 / 32768.0,
                24 => {
                    let raw = i32::from_le_bytes([
                        chunk[0],
                        chunk[1],
                        chunk[2],
                        if chunk[2] & 0x80 != 0 { 0xff } else { 0 },
                    ]);
                    raw as f32 / 8_388_608.0
                }
                32 => {
                    i32::from_le_bytes([chunk[0], chunk[1], chunk[2], chunk[3]]) as f32
                        / 2_147_483_648.0
                }
                _ => return Err(err("invalid_input", "unsupported WAV sample depth")),
            }
        };
        if !finite(value) {
            return Err(err("invalid_pcm", "WAV contains a non-finite float sample"));
        }
        out.extend_from_slice(&value.to_le_bytes());
    }
    Ok((info.rate, info.channels, out))
}

fn clamp(value: f32) -> f32 {
    value.clamp(-1.0, 1.0)
}

pub fn encode(
    pcm: &[u8],
    rate: u32,
    channels: usize,
    format: &str,
) -> Result<Vec<u8>, (String, String)> {
    if channels != 1 && channels != 2 {
        return Err(err("invalid_settings", "channels must be 1 or 2"));
    }
    if rate == 0 {
        return Err(err("invalid_settings", "sample rate must be positive"));
    }
    if pcm.len() % (4 * channels) != 0 {
        return Err(err("invalid_pcm", "PCM is not aligned to channel frames"));
    }
    if pcm.len() > MAX_BYTES {
        return Err(err(
            "allocation_bound",
            "PCM exceeds the maximum supported size",
        ));
    }
    let bits = match format {
        "s16" => 16,
        "s24" => 24,
        "s32" | "f32" => 32,
        _ => {
            return Err(err(
                "invalid_settings",
                "sample_format must be s16, s24, s32, or f32",
            ))
        }
    };
    let is_float = format == "f32";
    let samples = pcm.len() / 4;
    let bytes_per_sample = bits / 8;
    let data_len = samples
        .checked_mul(bytes_per_sample)
        .ok_or_else(|| err("allocation_bound", "WAV output size overflows"))?;
    let data_padding = data_len & 1;
    let riff_size = 36usize
        .checked_add(data_len)
        .and_then(|size| size.checked_add(data_padding))
        .ok_or_else(|| err("allocation_bound", "WAV output size overflows"))?;
    if riff_size > u32::MAX as usize || data_len > u32::MAX as usize {
        return Err(err("allocation_bound", "WAV exceeds RIFF's 4 GiB limit"));
    }
    let mut out = Vec::with_capacity(8 + riff_size);
    out.extend_from_slice(b"RIFF");
    out.extend_from_slice(&(riff_size as u32).to_le_bytes());
    out.extend_from_slice(b"WAVE");
    out.extend_from_slice(b"fmt ");
    out.extend_from_slice(&16u32.to_le_bytes());
    out.extend_from_slice(&(if is_float { 3u16 } else { 1u16 }).to_le_bytes());
    out.extend_from_slice(&(channels as u16).to_le_bytes());
    out.extend_from_slice(&rate.to_le_bytes());
    let byte_rate = rate
        .checked_mul(channels as u32)
        .and_then(|v| v.checked_mul(bytes_per_sample as u32))
        .ok_or_else(|| err("allocation_bound", "WAV byte rate overflows"))?;
    out.extend_from_slice(&byte_rate.to_le_bytes());
    out.extend_from_slice(&((channels * bytes_per_sample) as u16).to_le_bytes());
    out.extend_from_slice(&(bits as u16).to_le_bytes());
    out.extend_from_slice(b"data");
    out.extend_from_slice(&(data_len as u32).to_le_bytes());
    for chunk in pcm.chunks_exact(4) {
        let sample = f32::from_le_bytes([chunk[0], chunk[1], chunk[2], chunk[3]]);
        if !finite(sample) {
            return Err(err("invalid_pcm", "PCM contains a non-finite sample"));
        }
        let value = clamp(sample);
        match format {
            "f32" => out.extend_from_slice(&sample.to_le_bytes()),
            "s16" => out.extend_from_slice(
                &(if value <= -1.0 {
                    i16::MIN
                } else if value >= 1.0 {
                    i16::MAX
                } else {
                    (value * 32767.0).round() as i16
                })
                .to_le_bytes(),
            ),
            "s24" => {
                let n = if value <= -1.0 {
                    -8_388_608
                } else if value >= 1.0 {
                    8_388_607
                } else {
                    (value * 8_388_607.0).round() as i32
                };
                out.extend_from_slice(&n.to_le_bytes()[..3]);
            }
            "s32" => {
                let n = if value <= -1.0 {
                    i32::MIN
                } else if value >= 1.0 {
                    i32::MAX
                } else {
                    (value as f64 * 2_147_483_647.0).round() as i32
                };
                out.extend_from_slice(&n.to_le_bytes());
            }
            _ => unreachable!(),
        }
    }
    if data_padding != 0 {
        out.push(0);
    }
    Ok(out)
}
