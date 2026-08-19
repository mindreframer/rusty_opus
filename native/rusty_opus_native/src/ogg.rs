//! Ogg Opus whole-blob reencode via pure-Rust `ruopus`.

use std::panic::{catch_unwind, AssertUnwindSafe};

use rustler::{Binary, Env, NewBinary};

fn tuple(reason: &str, message: &str) -> (String, String) {
    (reason.to_string(), message.to_string())
}

/// Demux an Ogg Opus blob, re-encode PCM at `bitrate` bits/s, remux Ogg Opus.
#[allow(clippy::needless_pass_by_value)]
pub fn ogg_reencode<'a>(
    env: Env<'a>,
    blob: Binary<'a>,
    bitrate: u32,
) -> Result<Binary<'a>, (String, String)> {
    if bitrate == 0 {
        return Err(tuple("invalid_settings", "bitrate must be greater than 0"));
    }
    if blob.is_empty() {
        return Err(tuple("invalid_input", "Ogg Opus blob must not be empty"));
    }

    let bytes = blob.as_slice().to_vec();

    let result = catch_unwind(AssertUnwindSafe(|| reencode_inner(&bytes, bitrate)));
    match result {
        Ok(Ok(out)) => {
            let mut binary = NewBinary::new(env, out.len());
            binary.as_mut_slice().copy_from_slice(&out);
            Ok(binary.into())
        }
        Ok(Err(err)) => Err(err),
        Err(_) => Err(tuple(
            "codec_panicked",
            "ruopus panicked while reencoding Ogg Opus; panic contained",
        )),
    }
}

fn reencode_inner(bytes: &[u8], bitrate: u32) -> Result<Vec<u8>, (String, String)> {
    let (pcm, head) = ruopus::decode_ogg_opus(bytes)
        .map_err(|e| tuple("decode_failed", &format!("failed to decode Ogg Opus: {e}")))?;

    let channels = usize::from(head.channel_count);
    if channels != 1 && channels != 2 {
        return Err(tuple(
            "invalid_input",
            &format!("unsupported channel count {channels} (need 1 or 2)"),
        ));
    }
    if pcm.len() % channels != 0 {
        return Err(tuple(
            "invalid_pcm",
            "decoded PCM length is not a multiple of channel count",
        ));
    }

    // `encode_ogg_opus` panics on bad channel/pcm shape; those are checked above.
    // It also `.expect`s encode_auto; that panic is contained by the outer catch_unwind.
    Ok(ruopus::encode_ogg_opus(&pcm, channels, bitrate))
}
