//! Opus encoder resources and NIFs.

use std::panic::{catch_unwind, AssertUnwindSafe};
use std::sync::{
    atomic::{AtomicBool, AtomicUsize, Ordering},
    Mutex,
};

use opus_rs::{Application, OpusEncoder};
use rustler::{Binary, Env, NewBinary, NifMap, Resource, ResourceArc};

static ENCODERS: AtomicUsize = AtomicUsize::new(0);

/// Encoder settings carried across the boundary as a map. All fields are optional;
/// an omitted field keeps the codec default.
#[derive(Debug, Default, NifMap)]
pub struct NativeSettings {
    pub bitrate: Option<i64>,
    pub complexity: Option<i64>,
    pub cbr: Option<bool>,
    pub fec: Option<bool>,
    pub packet_loss: Option<i64>,
}

struct EncoderInner {
    encoder: OpusEncoder,
    channels: usize,
}

pub struct EncoderResource {
    inner: Mutex<EncoderInner>,
    closed: AtomicBool,
}

impl Resource for EncoderResource {}

impl Drop for EncoderResource {
    fn drop(&mut self) {
        ENCODERS.fetch_sub(1, Ordering::SeqCst);
    }
}

fn tuple(reason: &str, message: &str) -> (String, String) {
    (reason.to_string(), message.to_string())
}

fn apply_settings(encoder: &mut OpusEncoder, settings: &NativeSettings) -> Result<(), String> {
    // Settings are validated in Elixir (rate <= 48000, bitrate >= 0, complexity
    // 0..10, packet_loss 0..100), so i64 -> i32 cannot truncate meaningful values;
    // the checked conversion still keeps the boundary honest.
    if let Some(bitrate) = settings.bitrate {
        encoder.bitrate_bps =
            i32::try_from(bitrate).map_err(|_| "bitrate out of i32 range".to_string())?;
    }
    if let Some(complexity) = settings.complexity {
        encoder.complexity =
            i32::try_from(complexity).map_err(|_| "complexity out of i32 range".to_string())?;
    }
    if let Some(cbr) = settings.cbr {
        encoder.use_cbr = cbr;
    }
    if let Some(fec) = settings.fec {
        encoder.use_inband_fec = fec;
    }
    if let Some(packet_loss) = settings.packet_loss {
        encoder.packet_loss_perc =
            i32::try_from(packet_loss).map_err(|_| "packet_loss out of i32 range".to_string())?;
    }
    Ok(())
}

fn to_f32s(bytes: &[u8]) -> Result<Vec<f32>, String> {
    if bytes.len() % 4 != 0 {
        return Err("PCM byte length must be a multiple of 4".to_string());
    }
    let mut samples = Vec::with_capacity(bytes.len() / 4);
    for chunk in bytes.chunks_exact(4) {
        let arr: [u8; 4] = chunk
            .try_into()
            .map_err(|_| "invalid PCM chunk".to_string())?;
        samples.push(f32::from_le_bytes(arr));
    }
    Ok(samples)
}

#[allow(clippy::needless_pass_by_value)]
pub fn encoder_new(
    rate: i64,
    channels: usize,
    application: String,
    settings: NativeSettings,
) -> Result<ResourceArc<EncoderResource>, (String, String)> {
    let application = match application.as_str() {
        "voip" => Some(Application::Voip),
        "audio" => Some(Application::Audio),
        "restricted_low_delay" => Some(Application::RestrictedLowDelay),
        _ => None,
    }
    .ok_or_else(|| tuple("invalid_application", "unknown application"))?;

    let rate = i32::try_from(rate).map_err(|_| tuple("invalid_rate", "rate out of i32 range"))?;
    let mut encoder =
        OpusEncoder::new(rate, channels, application).map_err(|m| tuple("invalid_settings", m))?;
    apply_settings(&mut encoder, &settings).map_err(|m| tuple("invalid_settings", &m))?;

    ENCODERS.fetch_add(1, Ordering::SeqCst);
    Ok(ResourceArc::new(EncoderResource {
        inner: Mutex::new(EncoderInner { encoder, channels }),
        closed: AtomicBool::new(false),
    }))
}

fn encode_frame<'a>(
    env: Env<'a>,
    resource: &ResourceArc<EncoderResource>,
    inner: &mut EncoderInner,
    samples: &[f32],
    frame_size: usize,
) -> Result<Binary<'a>, (String, String)> {
    let mut output = vec![0u8; 4096];
    // opus-rs can panic on malformed internal state; contain it so the panic never
    // unwinds across the NIF boundary. After a panic the encoder is marked closed
    // because its internal state may be inconsistent.
    let written = if let Ok(result) = catch_unwind(AssertUnwindSafe(|| {
        inner.encoder.encode(samples, frame_size, &mut output)
    })) {
        result.map_err(|m| tuple("encode_failed", m))?
    } else {
        resource.closed.store(true, Ordering::SeqCst);
        return Err(tuple(
            "codec_panicked",
            "opus-rs encoder panicked; encoder is now unusable",
        ));
    };

    let mut binary = NewBinary::new(env, written);
    binary.as_mut_slice().copy_from_slice(&output[..written]);
    Ok(binary.into())
}

#[allow(clippy::needless_pass_by_value)]
#[allow(clippy::significant_drop_tightening)] // the guard must live across the encode call
pub fn encoder_encode<'a>(
    env: Env<'a>,
    resource: ResourceArc<EncoderResource>,
    pcm: Binary<'a>,
    frame_size: usize,
) -> Result<Binary<'a>, (String, String)> {
    if resource.closed.load(Ordering::SeqCst) {
        return Err(tuple("closed", "encoder is closed"));
    }
    let samples = to_f32s(pcm.as_slice()).map_err(|m| tuple("invalid_pcm", &m))?;
    let mut inner = resource
        .inner
        .lock()
        .map_err(|_| tuple("poisoned", "encoder mutex is poisoned"))?;

    let expected = inner.channels * frame_size;
    if samples.len() != expected {
        return Err(tuple(
            "invalid_input",
            &format!(
                "expected {expected} f32 samples (frame_size {frame_size} x {} channels), got {}",
                inner.channels,
                samples.len()
            ),
        ));
    }

    encode_frame(env, &resource, &mut inner, &samples, frame_size)
}

#[allow(clippy::needless_pass_by_value)]
#[allow(clippy::significant_drop_tightening)] // the guard must live across every encode call
pub fn encoder_encode_many<'a>(
    env: Env<'a>,
    resource: ResourceArc<EncoderResource>,
    pcm: Binary<'a>,
    frame_size: usize,
) -> Result<Vec<Binary<'a>>, (String, String)> {
    if resource.closed.load(Ordering::SeqCst) {
        return Err(tuple("closed", "encoder is closed"));
    }
    if frame_size == 0 {
        return Err(tuple("invalid_input", "frame_size must be greater than 0"));
    }

    let samples = to_f32s(pcm.as_slice()).map_err(|m| tuple("invalid_pcm", &m))?;
    if samples.is_empty() {
        return Ok(Vec::new());
    }

    let mut inner = resource
        .inner
        .lock()
        .map_err(|_| tuple("poisoned", "encoder mutex is poisoned"))?;

    let samples_per_frame = inner.channels * frame_size;
    let mut packets = Vec::new();
    let mut offset = 0;

    while offset < samples.len() {
        let chunk_end = (offset + samples_per_frame).min(samples.len());
        let mut frame = samples[offset..chunk_end].to_vec();
        if frame.len() < samples_per_frame {
            frame.resize(samples_per_frame, 0.0);
        }

        let packet = encode_frame(env, &resource, &mut inner, &frame, frame_size)?;
        packets.push(packet);
        offset = chunk_end;
    }

    Ok(packets)
}

#[allow(clippy::needless_pass_by_value)]
#[allow(clippy::significant_drop_tightening)] // the guard must live across the set call
pub fn encoder_set(
    resource: ResourceArc<EncoderResource>,
    settings: NativeSettings,
) -> Result<(), (String, String)> {
    if resource.closed.load(Ordering::SeqCst) {
        return Err(tuple("closed", "encoder is closed"));
    }
    let mut inner = resource
        .inner
        .lock()
        .map_err(|_| tuple("poisoned", "encoder mutex is poisoned"))?;
    apply_settings(&mut inner.encoder, &settings).map_err(|m| tuple("invalid_settings", &m))?;
    Ok(())
}

#[allow(clippy::needless_pass_by_value)] // NIF boundary takes ownership
#[allow(clippy::unnecessary_wraps)] // kept as `Result` for boundary consistency; close is infallible
pub fn encoder_close(resource: ResourceArc<EncoderResource>) -> Result<(), (String, String)> {
    resource.closed.store(true, Ordering::SeqCst);
    Ok(())
}

/// Number of live encoder resources, used by resource-baseline tests.
pub fn encoder_count() -> usize {
    ENCODERS.load(Ordering::SeqCst)
}
