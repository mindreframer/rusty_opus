//! Opus decoder resources and NIFs.

use std::panic::{catch_unwind, AssertUnwindSafe};
use std::sync::{
    atomic::{AtomicBool, AtomicUsize, Ordering},
    Mutex,
};

use opus_rs::OpusDecoder;
use rustler::{Binary, Env, NewBinary, Resource, ResourceArc};

static DECODERS: AtomicUsize = AtomicUsize::new(0);

struct DecoderInner {
    decoder: OpusDecoder,
    channels: usize,
}

pub struct DecoderResource {
    inner: Mutex<DecoderInner>,
    closed: AtomicBool,
}

impl Resource for DecoderResource {}

impl Drop for DecoderResource {
    fn drop(&mut self) {
        DECODERS.fetch_sub(1, Ordering::SeqCst);
    }
}

fn tuple(reason: &str, message: &str) -> (String, String) {
    (reason.to_string(), message.to_string())
}

#[allow(clippy::needless_pass_by_value)] // NIF boundary takes ownership
pub fn decoder_new(
    rate: i64,
    channels: usize,
) -> Result<ResourceArc<DecoderResource>, (String, String)> {
    let rate = i32::try_from(rate).map_err(|_| tuple("invalid_rate", "rate out of i32 range"))?;
    let decoder = OpusDecoder::new(rate, channels).map_err(|m| tuple("invalid_settings", m))?;

    DECODERS.fetch_add(1, Ordering::SeqCst);
    Ok(ResourceArc::new(DecoderResource {
        inner: Mutex::new(DecoderInner { decoder, channels }),
        closed: AtomicBool::new(false),
    }))
}

#[allow(clippy::needless_pass_by_value)]
#[allow(clippy::significant_drop_tightening)] // the guard must live across the decode call
pub fn decoder_decode<'a>(
    env: Env<'a>,
    resource: ResourceArc<DecoderResource>,
    packet: Binary<'a>,
    frame_size: usize,
) -> Result<Binary<'a>, (String, String)> {
    if resource.closed.load(Ordering::SeqCst) {
        return Err(tuple("closed", "decoder is closed"));
    }
    let mut inner = resource
        .inner
        .lock()
        .map_err(|_| tuple("poisoned", "decoder mutex is poisoned"))?;

    let mut output = vec![0f32; inner.channels * frame_size];
    // opus-rs can panic on hostile packets (e.g. corrupt SILK parameters); contain
    // the panic at the NIF boundary and poison the decoder afterwards.
    let written = if let Ok(result) = catch_unwind(AssertUnwindSafe(|| {
        inner
            .decoder
            .decode(packet.as_slice(), frame_size, &mut output)
    })) {
        result.map_err(|m| tuple("decode_failed", m))?
    } else {
        resource.closed.store(true, Ordering::SeqCst);
        return Err(tuple(
            "codec_panicked",
            "opus-rs decoder panicked; decoder is now unusable",
        ));
    };

    let total = written.saturating_mul(inner.channels).min(output.len());
    let mut binary = NewBinary::new(env, total * 4);
    for (i, sample) in output[..total].iter().enumerate() {
        let bytes = sample.to_le_bytes();
        let start = i * 4;
        binary.as_mut_slice()[start..start + 4].copy_from_slice(&bytes);
    }
    Ok(binary.into())
}

#[allow(clippy::needless_pass_by_value)] // NIF boundary takes ownership
#[allow(clippy::unnecessary_wraps)] // kept as `Result` for boundary consistency; close is infallible
pub fn decoder_close(resource: ResourceArc<DecoderResource>) -> Result<(), (String, String)> {
    resource.closed.store(true, Ordering::SeqCst);
    Ok(())
}

/// Number of live decoder resources, used by resource-baseline tests.
pub fn decoder_count() -> usize {
    DECODERS.load(Ordering::SeqCst)
}
