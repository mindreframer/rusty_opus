//! In-memory MPEG Layer III adapter around the pinned pure-Rust `rusty_mp3` crate.
#![allow(clippy::all)]

use std::panic::{catch_unwind, AssertUnwindSafe};

use rustler::{Binary, Env, NewBinary, NifMap};
use rusty_mp3::{header::FrameHeader, Mp3Decoder, Mp3Encoder, Mp3EncoderConfig};

const MAX_BYTES: usize = 256 * 1024 * 1024;

#[derive(Debug, NifMap)]
pub struct Mp3Settings {
    pub bitrate: i64,
    pub vbr: bool,
}

fn err(reason: &str, message: impl Into<String>) -> (String, String) {
    (reason.to_string(), message.into())
}

fn supported_rate(rate: i64) -> bool {
    matches!(
        rate,
        8_000 | 11_025 | 12_000 | 16_000 | 22_050 | 24_000 | 32_000 | 44_100 | 48_000
    )
}

fn valid_bitrate(rate: i64, bitrate: i64) -> bool {
    let kbps = bitrate / 1000;
    if bitrate <= 0 || bitrate % 1000 != 0 {
        return false;
    }
    let v1 = [
        32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320,
    ];
    let v2 = [8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160];
    let table = if rate >= 32_000 { &v1[..] } else { &v2[..] };
    table.contains(&kbps)
}

fn validate_stream(bytes: &[u8]) -> Result<(), (String, String)> {
    let mut start = 0usize;
    if bytes.starts_with(b"ID3") {
        if bytes.len() < 10 {
            return Err(err("decode_failed", "truncated ID3v2 header"));
        }
        if bytes[6..10].iter().any(|byte| byte & 0x80 != 0) {
            return Err(err("decode_failed", "invalid ID3v2 synchsafe size"));
        }
        let tag_size = (usize::from(bytes[6]) << 21)
            | (usize::from(bytes[7]) << 14)
            | (usize::from(bytes[8]) << 7)
            | usize::from(bytes[9]);
        let footer = if bytes[5] & 0x10 != 0 { 10 } else { 0 };
        start = 10usize
            .checked_add(tag_size)
            .and_then(|size| size.checked_add(footer))
            .ok_or_else(|| err("allocation_bound", "ID3v2 size overflows"))?;
        if start > bytes.len() {
            return Err(err("decode_failed", "truncated ID3v2 tag"));
        }
    }

    let mut pos = start;
    let mut frames = 0usize;
    let mut first: Option<(u32, usize)> = None;
    while pos + 4 <= bytes.len() {
        let header = match FrameHeader::parse([
            bytes[pos],
            bytes[pos + 1],
            bytes[pos + 2],
            bytes[pos + 3],
        ]) {
            Ok(header) => header,
            Err(_) if frames == 0 => {
                pos += 1;
                continue;
            }
            Err(_) => return Err(err("decode_failed", "malformed MP3 frame header")),
        };
        let frame_size = header.frame_size();
        if frame_size < 4
            || pos
                .checked_add(frame_size)
                .is_none_or(|end| end > bytes.len())
        {
            return Err(err("decode_failed", "truncated MP3 frame"));
        }
        let channels = header.channel_mode.channels();
        if let Some((rate, expected_channels)) = first {
            if rate != header.sample_rate || expected_channels != channels {
                return Err(err(
                    "decode_failed",
                    "MP3 changes sample rate or channel count midstream",
                ));
            }
        } else {
            first = Some((header.sample_rate, channels));
        }
        frames += 1;
        pos += frame_size;
    }
    if frames == 0 {
        return Err(err(
            "decode_failed",
            "input contains no valid MPEG Layer III frames",
        ));
    }
    if pos != bytes.len() {
        return Err(err("decode_failed", "truncated MP3 frame header"));
    }
    Ok(())
}

fn output<'a>(env: Env<'a>, bytes: Vec<u8>) -> Binary<'a> {
    let mut binary = NewBinary::new(env, bytes.len());
    binary.as_mut_slice().copy_from_slice(&bytes);
    binary.into()
}

pub fn decode<'a>(
    env: Env<'a>,
    blob: Binary<'a>,
) -> Result<(i64, usize, Binary<'a>), (String, String)> {
    if blob.is_empty() {
        return Err(err("invalid_input", "MP3 blob must not be empty"));
    }
    if blob.len() > MAX_BYTES {
        return Err(err(
            "allocation_bound",
            "MP3 blob exceeds the maximum supported size",
        ));
    }
    let bytes = blob.as_slice().to_vec();
    validate_stream(&bytes)?;
    let result = catch_unwind(AssertUnwindSafe(|| {
        let mut decoder = Mp3Decoder::new();
        decoder.push(&bytes);
        decoder.flush();
        let mut rate: Option<u32> = None;
        let mut channels: Option<usize> = None;
        let mut pcm = Vec::<f32>::new();
        loop {
            match decoder.next_frame() {
                Ok(frame) => {
                    if frame.channels == 0
                        || frame.channels > 2
                        || !frame
                            .sample_rate
                            .checked_mul(frame.channels as u32)
                            .is_some()
                    {
                        return Err(err(
                            "decode_failed",
                            "MP3 reported unsupported channel metadata",
                        ));
                    }
                    match (rate, channels) {
                        (Some(r), Some(c))
                            if r != frame.sample_rate || c != frame.channels as usize =>
                        {
                            return Err(err(
                                "decode_failed",
                                "MP3 changes sample rate or channel count midstream",
                            ));
                        }
                        _ => {
                            rate = Some(frame.sample_rate);
                            channels = Some(frame.channels as usize);
                        }
                    }
                    if pcm
                        .len()
                        .checked_add(frame.samples.len())
                        .filter(|&n| n.checked_mul(4).is_some_and(|b| b <= MAX_BYTES))
                        .is_none()
                    {
                        return Err(err(
                            "allocation_bound",
                            "decoded MP3 PCM exceeds the maximum supported size",
                        ));
                    }
                    if frame.samples.iter().any(|s| !s.is_finite()) {
                        return Err(err(
                            "decode_failed",
                            "MP3 decoder returned a non-finite sample",
                        ));
                    }
                    pcm.extend_from_slice(&frame.samples);
                }
                Err(rusty_mp3::Error::Eof) => break,
                Err(rusty_mp3::Error::Again) => continue,
                Err(error) => return Err(err("decode_failed", error.to_string())),
            }
        }
        let rate = rate.ok_or_else(|| {
            err(
                "decode_failed",
                "input contains no valid MPEG Layer III frames",
            )
        })?;
        let channels =
            channels.ok_or_else(|| err("decode_failed", "MP3 channel metadata is missing"))?;
        let mut bytes = Vec::with_capacity(pcm.len() * 4);
        for sample in pcm {
            bytes.extend_from_slice(&sample.to_le_bytes());
        }
        Ok((i64::from(rate), channels, bytes))
    }));
    match result {
        Ok(Ok((rate, channels, pcm))) => Ok((rate, channels, output(env, pcm))),
        Ok(Err(error)) => Err(error),
        Err(_) => Err(err("codec_panicked", "native MP3 panic contained")),
    }
}

pub fn encode<'a>(
    env: Env<'a>,
    pcm: Binary<'a>,
    rate: i64,
    channels: usize,
    settings: Mp3Settings,
) -> Result<Binary<'a>, (String, String)> {
    if rate <= 0 || !supported_rate(rate) {
        return Err(err("invalid_rate", "MP3 sample rate is unsupported"));
    }
    if channels != 1 && channels != 2 {
        return Err(err("invalid_settings", "MP3 channels must be 1 or 2"));
    }
    if settings.bitrate <= 0 || !valid_bitrate(rate, settings.bitrate) {
        return Err(err(
            "invalid_settings",
            "bitrate is not a standard MPEG Layer III bitrate for this sample rate",
        ));
    }
    if pcm.len() == 0 {
        return Err(err("invalid_input", "MP3 cannot encode empty PCM"));
    }
    if pcm.len() % 4 != 0 {
        return Err(err(
            "invalid_pcm",
            "PCM byte length must be a multiple of 4",
        ));
    }
    if pcm.len() > MAX_BYTES {
        return Err(err(
            "allocation_bound",
            "PCM exceeds the maximum supported size",
        ));
    }
    let mut samples = Vec::with_capacity(pcm.len() / 4);
    for chunk in pcm.as_slice().chunks_exact(4) {
        let value = f32::from_le_bytes([chunk[0], chunk[1], chunk[2], chunk[3]]);
        if !value.is_finite() {
            return Err(err("invalid_pcm", "PCM samples must be finite"));
        }
        samples.push(value.clamp(-1.0, 1.0));
    }
    if samples.len() % channels != 0 {
        return Err(err("invalid_pcm", "PCM is not aligned to channel frames"));
    }
    let kbps = u32::try_from(settings.bitrate / 1000)
        .map_err(|_| err("invalid_settings", "bitrate is out of range"))?;
    let config = Mp3EncoderConfig {
        bitrate_kbps: kbps,
        // rusty_mp3's VBR setting is an average-kbps target, not a quality index.
        vbr_quality: settings.vbr.then_some(kbps as f32),
    };
    let result = catch_unwind(AssertUnwindSafe(|| {
        let mut encoder = Mp3Encoder::new(config);
        encoder
            .push_pcm_f32(&samples, channels as u16, rate as u32)
            .map_err(|e| err("encode_failed", e.to_string()))?;
        encoder.finish();
        let mut out = Vec::new();
        loop {
            match encoder.next_packet() {
                Ok(packet) => {
                    if out
                        .len()
                        .checked_add(packet.len())
                        .filter(|&n| n <= MAX_BYTES)
                        .is_none()
                    {
                        return Err(err(
                            "allocation_bound",
                            "encoded MP3 exceeds the maximum supported size",
                        ));
                    }
                    out.extend_from_slice(&packet);
                }
                Err(rusty_mp3::Error::Eof) => break,
                Err(rusty_mp3::Error::Again) => continue,
                Err(e) => return Err(err("encode_failed", e.to_string())),
            }
        }
        if out.is_empty() {
            return Err(err("encode_failed", "MP3 encoder produced no frames"));
        }
        Ok(out)
    }));
    match result {
        Ok(Ok(bytes)) => Ok(output(env, bytes)),
        Ok(Err(error)) => Err(error),
        Err(_) => Err(err("codec_panicked", "native MP3 panic contained")),
    }
}
