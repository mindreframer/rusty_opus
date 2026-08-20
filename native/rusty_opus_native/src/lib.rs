//! `RustyOpus` native NIF library.
//!
//! Wires the deterministic smoke/error boundary, the Opus encoder/decoder
//! resources around the pinned `opus-rs` codec, and Ogg Opus blob reencode
//! via thin in-crate Ogg glue + `opus-rs` (see ADR003).

use std::panic::{catch_unwind, AssertUnwindSafe};

use rustler::{Atom, Env, Term};

mod atoms {
    rustler::atoms! {
        ok,
        error,
        native,
        contained_panic
    }
}

mod decoder;
mod encoder;
#[allow(clippy::all, clippy::pedantic, clippy::nursery)]
mod mp3;
#[allow(clippy::all, clippy::pedantic, clippy::nursery)]
mod ogg;
#[allow(clippy::all, clippy::pedantic, clippy::nursery)]
mod wav;

use decoder::DecoderResource;
use encoder::{EncoderResource, NativeSettings};
use mp3::Mp3Settings;
use ogg::ReencodeSettings;

#[rustler::nif]
fn smoke() -> (Atom, &'static str) {
    (atoms::ok(), env!("CARGO_PKG_VERSION"))
}

#[rustler::nif]
fn translated_error() -> (Atom, Atom, &'static str) {
    (
        atoms::error(),
        atoms::native(),
        "deterministic native error",
    )
}

#[rustler::nif]
fn contained_panic() -> (Atom, Atom, &'static str) {
    let result = catch_unwind(AssertUnwindSafe(|| {
        std::panic::resume_unwind(Box::new("contained test panic"));
    }));
    match result {
        Ok(()) => (atoms::ok(), atoms::native(), "unexpected success"),
        Err(_) => (
            atoms::error(),
            atoms::contained_panic(),
            "native panic contained",
        ),
    }
}

#[rustler::nif]
fn encoder_new(
    rate: i64,
    channels: usize,
    application: String,
    settings: NativeSettings,
) -> Result<rustler::ResourceArc<EncoderResource>, (String, String)> {
    encoder::encoder_new(rate, channels, application, settings)
}

#[rustler::nif(schedule = "DirtyCpu")]
fn encoder_encode<'a>(
    env: rustler::Env<'a>,
    resource: rustler::ResourceArc<EncoderResource>,
    pcm: rustler::Binary<'a>,
    frame_size: usize,
) -> Result<rustler::Binary<'a>, (String, String)> {
    encoder::encoder_encode(env, resource, pcm, frame_size)
}

#[rustler::nif(schedule = "DirtyCpu")]
fn encoder_encode_many<'a>(
    env: rustler::Env<'a>,
    resource: rustler::ResourceArc<EncoderResource>,
    pcm: rustler::Binary<'a>,
    frame_size: usize,
) -> Result<Vec<rustler::Binary<'a>>, (String, String)> {
    encoder::encoder_encode_many(env, resource, pcm, frame_size)
}

#[rustler::nif]
fn encoder_set(
    resource: rustler::ResourceArc<EncoderResource>,
    settings: NativeSettings,
) -> Result<(), (String, String)> {
    encoder::encoder_set(resource, settings)
}

#[rustler::nif]
fn encoder_close(resource: rustler::ResourceArc<EncoderResource>) -> Result<(), (String, String)> {
    encoder::encoder_close(resource)
}

#[rustler::nif]
fn encoder_count() -> usize {
    encoder::encoder_count()
}

#[rustler::nif]
fn decoder_new(
    rate: i64,
    channels: usize,
) -> Result<rustler::ResourceArc<DecoderResource>, (String, String)> {
    decoder::decoder_new(rate, channels)
}

#[rustler::nif(schedule = "DirtyCpu")]
fn decoder_decode<'a>(
    env: rustler::Env<'a>,
    resource: rustler::ResourceArc<DecoderResource>,
    packet: rustler::Binary<'a>,
    frame_size: usize,
) -> Result<rustler::Binary<'a>, (String, String)> {
    decoder::decoder_decode(env, resource, packet, frame_size)
}

#[rustler::nif(schedule = "DirtyCpu")]
fn decoder_decode_many<'a>(
    env: rustler::Env<'a>,
    resource: rustler::ResourceArc<DecoderResource>,
    packets: Vec<rustler::Binary<'a>>,
    frame_size: usize,
) -> Result<rustler::Binary<'a>, (String, String)> {
    decoder::decoder_decode_many(env, resource, packets, frame_size)
}

#[rustler::nif]
fn decoder_close(resource: rustler::ResourceArc<DecoderResource>) -> Result<(), (String, String)> {
    decoder::decoder_close(resource)
}

#[rustler::nif]
fn decoder_count() -> usize {
    decoder::decoder_count()
}

#[rustler::nif(schedule = "DirtyCpu")]
fn wav_decode<'a>(
    env: rustler::Env<'a>,
    blob: rustler::Binary<'a>,
) -> Result<(i64, usize, rustler::Binary<'a>), (String, String)> {
    let result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        wav::decode(blob.as_slice())
    }));
    match result {
        Ok(Ok((rate, channels, pcm))) => {
            let mut binary = rustler::NewBinary::new(env, pcm.len());
            binary.as_mut_slice().copy_from_slice(&pcm);
            Ok((i64::from(rate), channels, binary.into()))
        }
        Ok(Err(error)) => Err(error),
        Err(_) => Err((
            "codec_panicked".to_string(),
            "native WAV panic contained".to_string(),
        )),
    }
}

#[allow(clippy::all, clippy::pedantic, clippy::nursery)]
#[rustler::nif(schedule = "DirtyCpu")]
fn wav_encode<'a>(
    env: rustler::Env<'a>,
    pcm: rustler::Binary<'a>,
    rate: i64,
    channels: usize,
    sample_format: String,
) -> Result<rustler::Binary<'a>, (String, String)> {
    let result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        let rate = u32::try_from(rate).map_err(|_| {
            (
                "invalid_rate".to_string(),
                "sample rate is out of range".to_string(),
            )
        })?;
        wav::encode(pcm.as_slice(), rate, channels, &sample_format)
    }));
    match result {
        Ok(Ok(bytes)) => {
            let mut binary = rustler::NewBinary::new(env, bytes.len());
            binary.as_mut_slice().copy_from_slice(&bytes);
            Ok(binary.into())
        }
        Ok(Err(error)) => Err(error),
        Err(_) => Err((
            "codec_panicked".to_string(),
            "native WAV panic contained".to_string(),
        )),
    }
}

#[rustler::nif(schedule = "DirtyCpu")]
fn mp3_decode<'a>(
    env: rustler::Env<'a>,
    blob: rustler::Binary<'a>,
) -> Result<(i64, usize, rustler::Binary<'a>), (String, String)> {
    mp3::decode(env, blob)
}

#[allow(clippy::all, clippy::pedantic, clippy::nursery)]
#[rustler::nif(schedule = "DirtyCpu")]
fn mp3_encode<'a>(
    env: rustler::Env<'a>,
    pcm: rustler::Binary<'a>,
    rate: i64,
    channels: usize,
    settings: Mp3Settings,
) -> Result<rustler::Binary<'a>, (String, String)> {
    mp3::encode(env, pcm, rate, channels, settings)
}

#[rustler::nif(schedule = "DirtyCpu")]
fn ogg_decode<'a>(
    env: rustler::Env<'a>,
    blob: rustler::Binary<'a>,
) -> Result<(i64, usize, rustler::Binary<'a>), (String, String)> {
    ogg::ogg_decode(env, blob)
}

#[rustler::nif(schedule = "DirtyCpu")]
fn ogg_encode<'a>(
    env: rustler::Env<'a>,
    pcm: rustler::Binary<'a>,
    channels: usize,
    settings: ReencodeSettings,
) -> Result<rustler::Binary<'a>, (String, String)> {
    ogg::ogg_encode(env, pcm, channels, settings)
}

#[rustler::nif(schedule = "DirtyCpu")]
fn ogg_reencode<'a>(
    env: rustler::Env<'a>,
    blob: rustler::Binary<'a>,
    settings: ReencodeSettings,
) -> Result<rustler::Binary<'a>, (String, String)> {
    ogg::ogg_reencode(env, blob, settings)
}

fn load(env: Env<'_>, _load_info: Term<'_>) -> bool {
    env.register::<EncoderResource>().is_ok() && env.register::<DecoderResource>().is_ok()
}

rustler::init!("Elixir.RustyOpus.Native", load = load);
