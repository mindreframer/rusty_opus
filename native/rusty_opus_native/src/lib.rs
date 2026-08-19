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
mod ogg;

use decoder::DecoderResource;
use encoder::{EncoderResource, NativeSettings};
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
