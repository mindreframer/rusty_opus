//! Thin Ogg Opus (RFC 7845) demux/mux + `opus-rs` reencode for family 0.

use std::collections::VecDeque;
use std::panic::{catch_unwind, AssertUnwindSafe};

use opus_rs::{Application, OpusDecoder, OpusEncoder};
use rustler::{Binary, Env, NewBinary, NifMap};

use crate::encoder::NativeSettings;

const CAPTURE: &[u8; 4] = b"OggS";
const HEADER_LEN: usize = 27;
const NO_GRANULE: u64 = u64::MAX;
const MAX_PACKET_LEN: usize = 16 * 1024 * 1024;
/// Max Opus packet duration at 48 kHz (120 ms).
const MAX_FRAME_48K: usize = 5760;
/// Typical libopus / opus-rs encoder lookahead at 48 kHz (samples).
const PRE_SKIP: u16 = 312;
const SERIAL: u32 = 0x4f_70_75_73; // "Opus"

/// Speech-oriented reencode knobs (`FFmpeg`/`libopus` analogues).
#[derive(Debug, NifMap)]
pub struct ReencodeSettings {
    pub bitrate: i64,
    pub application: String,
    pub complexity: i64,
    pub cbr: bool,
    pub frame_duration_ms: i64,
}

fn tuple(reason: &str, message: &str) -> (String, String) {
    (reason.to_string(), message.to_string())
}

/// Demux an Ogg Opus blob, re-encode PCM with speech-oriented settings, remux.
#[allow(clippy::needless_pass_by_value)]
pub fn ogg_reencode<'a>(
    env: Env<'a>,
    blob: Binary<'a>,
    settings: ReencodeSettings,
) -> Result<Binary<'a>, (String, String)> {
    if blob.is_empty() {
        return Err(tuple("invalid_input", "Ogg Opus blob must not be empty"));
    }

    let bytes = blob.as_slice().to_vec();
    let result = catch_unwind(AssertUnwindSafe(|| reencode_inner(&bytes, &settings)));
    match result {
        Ok(Ok(out)) => {
            let mut binary = NewBinary::new(env, out.len());
            binary.as_mut_slice().copy_from_slice(&out);
            Ok(binary.into())
        }
        Ok(Err(err)) => Err(err),
        Err(_) => Err(tuple(
            "codec_panicked",
            "native panicked while reencoding Ogg Opus; panic contained",
        )),
    }
}

fn reencode_inner(bytes: &[u8], settings: &ReencodeSettings) -> Result<Vec<u8>, (String, String)> {
    let (pcm, channels) = decode_ogg_opus(bytes)?;
    encode_ogg_opus(&pcm, channels, settings)
}

fn parse_application(name: &str) -> Result<Application, (String, String)> {
    match name {
        "voip" => Ok(Application::Voip),
        "audio" => Ok(Application::Audio),
        "restricted_low_delay" => Ok(Application::RestrictedLowDelay),
        _ => Err(tuple(
            "invalid_settings",
            "application must be voip, audio, or restricted_low_delay",
        )),
    }
}

/// Samples/channel at 48 kHz for a supported Opus frame duration.
///
/// `opus-rs` rejects 40 ms / 60 ms on this path (Hybrid/CELT or frame-rate check).
fn frame_samples_48k(duration_ms: i64) -> Result<usize, (String, String)> {
    match duration_ms {
        10 => Ok(480),
        20 => Ok(960),
        40 | 60 => Err(tuple(
            "invalid_settings",
            "frame_duration_ms 40 and 60 are not supported by opus-rs at 48 kHz; use 10 or 20",
        )),
        _ => Err(tuple(
            "invalid_settings",
            "frame_duration_ms must be 10 or 20 (opus-rs limitation vs ffmpeg 60)",
        )),
    }
}

// ── Ogg CRC (RFC 3533) ─────────────────────────────────────────────────────

const CRC_POLY: u32 = 0x04C1_1DB7;
const CRC_TABLE: [u32; 256] = {
    let mut table = [0u32; 256];
    let mut i = 0u32;
    while i < 256 {
        let mut r = i << 24;
        let mut bit = 0;
        while bit < 8 {
            r = if r & 0x8000_0000 != 0 {
                (r << 1) ^ CRC_POLY
            } else {
                r << 1
            };
            bit += 1;
        }
        table[i as usize] = r;
        i += 1;
    }
    table
};

fn ogg_crc_update(mut crc: u32, data: &[u8]) -> u32 {
    for &b in data {
        crc = (crc << 8) ^ CRC_TABLE[((crc >> 24) as u8 ^ b) as usize];
    }
    crc
}

fn read_u64_le(slice: &[u8]) -> Result<u64, (String, String)> {
    let arr: [u8; 8] = slice
        .try_into()
        .map_err(|_| tuple("decode_failed", "truncated Ogg field"))?;
    Ok(u64::from_le_bytes(arr))
}

fn read_u32_le(slice: &[u8]) -> Result<u32, (String, String)> {
    let arr: [u8; 4] = slice
        .try_into()
        .map_err(|_| tuple("decode_failed", "truncated Ogg field"))?;
    Ok(u32::from_le_bytes(arr))
}

// ── Page parse / write ─────────────────────────────────────────────────────

struct Page<'a> {
    continued: bool,
    bos: bool,
    granule_position: u64,
    serial: u32,
    sequence: u32,
    segments: &'a [u8],
    body: &'a [u8],
}

fn parse_page(data: &[u8]) -> Result<(Page<'_>, usize), (String, String)> {
    if data.len() < HEADER_LEN {
        let msg = if data.starts_with(CAPTURE) || CAPTURE.starts_with(data) {
            "truncated Ogg page"
        } else {
            "missing OggS capture pattern"
        };
        return Err(tuple("decode_failed", msg));
    }
    if data[0..4] != *CAPTURE {
        return Err(tuple("decode_failed", "missing OggS capture pattern"));
    }
    if data[4] != 0 {
        return Err(tuple("decode_failed", "unsupported Ogg version"));
    }
    let n_segments = usize::from(data[26]);
    let body_start = HEADER_LEN + n_segments;
    if data.len() < body_start {
        return Err(tuple("decode_failed", "truncated Ogg page"));
    }
    let segments = &data[HEADER_LEN..body_start];
    let body_len: usize = segments.iter().map(|&v| usize::from(v)).sum();
    let total = body_start + body_len;
    if data.len() < total {
        return Err(tuple("decode_failed", "truncated Ogg page"));
    }
    let declared = read_u32_le(&data[22..26])?;
    let mut actual = ogg_crc_update(0, &data[..22]);
    actual = ogg_crc_update(actual, &[0, 0, 0, 0]);
    actual = ogg_crc_update(actual, &data[26..total]);
    if actual != declared {
        return Err(tuple("decode_failed", "Ogg page CRC mismatch"));
    }
    let flags = data[5];
    Ok((
        Page {
            continued: flags & 0x01 != 0,
            bos: flags & 0x02 != 0,
            granule_position: read_u64_le(&data[6..14])?,
            serial: read_u32_le(&data[14..18])?,
            sequence: read_u32_le(&data[18..22])?,
            segments,
            body: &data[body_start..total],
        },
        total,
    ))
}

fn write_page(
    serial: u32,
    seq: u32,
    granule: u64,
    header_type: u8,
    payload: &[u8],
) -> Result<Vec<u8>, (String, String)> {
    // A single OpusHead/OpusTags/audio packet always fits in ≤255 lacing values.
    write_page_packets(serial, seq, granule, header_type, &[payload])
}

/// Write one Ogg page containing one or more complete packets (no continued pages).
fn write_page_packets(
    serial: u32,
    seq: u32,
    granule: u64,
    header_type: u8,
    packets: &[&[u8]],
) -> Result<Vec<u8>, (String, String)> {
    let mut segments = Vec::new();
    let mut body = Vec::new();
    for pkt in packets {
        body.extend_from_slice(pkt);
        let mut remaining = pkt.len();
        if remaining == 0 {
            segments.push(0);
            continue;
        }
        while remaining >= 255 {
            segments.push(255);
            remaining -= 255;
        }
        #[allow(clippy::cast_possible_truncation)]
        segments.push(remaining as u8);
    }
    if segments.len() > 255 {
        return Err(tuple(
            "encode_failed",
            "Ogg page segment table exceeds 255 entries",
        ));
    }

    let mut page = Vec::with_capacity(HEADER_LEN + segments.len() + body.len());
    page.extend_from_slice(CAPTURE);
    page.push(0);
    page.push(header_type);
    page.extend_from_slice(&granule.to_le_bytes());
    page.extend_from_slice(&serial.to_le_bytes());
    page.extend_from_slice(&seq.to_le_bytes());
    page.extend_from_slice(&[0, 0, 0, 0]);
    #[allow(clippy::cast_possible_truncation)]
    page.push(segments.len() as u8);
    page.extend_from_slice(&segments);
    page.extend_from_slice(&body);
    let crc = ogg_crc_update(0, &page);
    page[22..26].copy_from_slice(&crc.to_le_bytes());
    Ok(page)
}

const fn segment_count_for_packet(len: usize) -> usize {
    if len == 0 {
        1
    } else {
        len.div_ceil(255)
    }
}

// ── Packet reassembly ──────────────────────────────────────────────────────

struct OggPacket {
    data: Vec<u8>,
    granule_position: u64,
}

struct PacketReader<'a> {
    data: &'a [u8],
    pos: usize,
    serial: Option<u32>,
    partial: Vec<u8>,
    have_partial: bool,
    poisoned: bool,
    last_sequence: Option<u32>,
    ready: VecDeque<OggPacket>,
}

impl<'a> PacketReader<'a> {
    #[must_use]
    const fn new(data: &'a [u8]) -> Self {
        Self {
            data,
            pos: 0,
            serial: None,
            partial: Vec::new(),
            have_partial: false,
            poisoned: false,
            last_sequence: None,
            ready: VecDeque::new(),
        }
    }

    fn next_packet(&mut self) -> Result<Option<OggPacket>, (String, String)> {
        loop {
            if let Some(pkt) = self.ready.pop_front() {
                return Ok(Some(pkt));
            }
            if !self.ingest_next_page() {
                return Ok(None);
            }
        }
    }

    fn ingest_next_page(&mut self) -> bool {
        while self.pos < self.data.len() {
            if let Ok((page, consumed)) = parse_page(&self.data[self.pos..]) {
                self.pos += consumed;
                match self.serial {
                    Some(serial) if page.serial != serial => continue,
                    None if !page.bos => continue,
                    None => {
                        self.serial = Some(page.serial);
                    }
                    Some(_) => {}
                }
                self.ingest(&page);
                return true;
            }
            // Truncation or corruption: try resync, else stop.
            if self.pos + 4 > self.data.len() {
                return false;
            }
            let from = self.pos + 1;
            match self.data[from..]
                .windows(4)
                .position(|w| w == CAPTURE.as_slice())
            {
                Some(off) => self.pos = from + off,
                None => return false,
            }
        }
        false
    }

    fn ingest(&mut self, page: &Page<'_>) {
        let consecutive = self
            .last_sequence
            .is_none_or(|prev| page.sequence == prev.wrapping_add(1));
        self.last_sequence = Some(page.sequence);

        if !consecutive || page.continued != self.have_partial {
            self.partial.clear();
            self.have_partial = false;
            self.poisoned = false;
        }

        let mut offset = 0usize;
        let mut last_complete_idx: Option<usize> = None;
        for &lacing in page.segments {
            let len = usize::from(lacing);
            if self.partial.len() + len > MAX_PACKET_LEN {
                self.poisoned = true;
                self.partial.clear();
            }
            if !self.poisoned {
                self.partial
                    .extend_from_slice(&page.body[offset..offset + len]);
            }
            offset += len;
            self.have_partial = true;
            if lacing < 255 {
                let data = std::mem::take(&mut self.partial);
                let poisoned = std::mem::take(&mut self.poisoned);
                self.have_partial = false;
                if !poisoned {
                    self.ready.push_back(OggPacket {
                        data,
                        granule_position: NO_GRANULE,
                    });
                    last_complete_idx = Some(self.ready.len() - 1);
                }
            }
        }
        if let Some(idx) = last_complete_idx {
            self.ready[idx].granule_position = page.granule_position;
        }
    }
}

// ── OpusHead ───────────────────────────────────────────────────────────────

struct OpusHead {
    channel_count: u8,
    pre_skip: u16,
    output_gain_q8: i16,
}

fn parse_opus_head(data: &[u8]) -> Result<OpusHead, (String, String)> {
    if data.len() < 19 || &data[0..8] != b"OpusHead" {
        return Err(tuple("decode_failed", "missing or malformed OpusHead"));
    }
    let version = data[8];
    if version >> 4 != 0 {
        return Err(tuple(
            "invalid_input",
            &format!("unsupported Ogg Opus version {version}"),
        ));
    }
    let channel_count = data[9];
    if channel_count == 0 || channel_count > 2 {
        return Err(tuple(
            "invalid_input",
            &format!("unsupported channel count {channel_count} (need 1 or 2)"),
        ));
    }
    let family = data[18];
    if family != 0 {
        return Err(tuple(
            "invalid_input",
            &format!("unsupported channel mapping family {family} (need 0)"),
        ));
    }
    Ok(OpusHead {
        channel_count,
        pre_skip: u16::from_le_bytes([data[10], data[11]]),
        output_gain_q8: i16::from_le_bytes([data[16], data[17]]),
    })
}

fn build_opus_head(channels: u8, pre_skip: u16) -> Vec<u8> {
    let mut head = Vec::with_capacity(19);
    head.extend_from_slice(b"OpusHead");
    head.push(1);
    head.push(channels);
    head.extend_from_slice(&pre_skip.to_le_bytes());
    head.extend_from_slice(&48_000u32.to_le_bytes());
    head.extend_from_slice(&0i16.to_le_bytes());
    head.push(0);
    head
}

fn build_opus_tags() -> Vec<u8> {
    let vendor = b"RustyOpus";
    let mut tags = Vec::new();
    tags.extend_from_slice(b"OpusTags");
    #[allow(clippy::cast_possible_truncation)]
    tags.extend_from_slice(&(vendor.len() as u32).to_le_bytes());
    tags.extend_from_slice(vendor);
    tags.extend_from_slice(&0u32.to_le_bytes());
    tags
}

// ── Decode / encode ────────────────────────────────────────────────────────

fn decode_ogg_opus(bytes: &[u8]) -> Result<(Vec<f32>, usize), (String, String)> {
    let mut reader = PacketReader::new(bytes);
    let head_pkt = reader
        .next_packet()?
        .ok_or_else(|| tuple("decode_failed", "failed to decode Ogg Opus: no packets"))?;
    let head = parse_opus_head(&head_pkt.data)?;
    let channels = usize::from(head.channel_count);

    let tags = reader.next_packet()?.ok_or_else(|| {
        tuple(
            "decode_failed",
            "failed to decode Ogg Opus: missing OpusTags",
        )
    })?;
    if tags.data.len() < 8 || &tags.data[0..8] != b"OpusTags" {
        return Err(tuple(
            "decode_failed",
            "failed to decode Ogg Opus: bad OpusTags",
        ));
    }

    let mut decoder = OpusDecoder::new(48_000, channels).map_err(|e| {
        tuple(
            "decode_failed",
            &format!("failed to open Opus decoder: {e}"),
        )
    })?;

    let mut pcm: Vec<f32> = Vec::new();
    let mut final_granule = 0u64;
    let mut frame_buf = vec![0.0f32; MAX_FRAME_48K * channels];

    while let Some(pkt) = reader.next_packet()? {
        if pkt.data.is_empty() {
            continue;
        }
        let n = decoder
            .decode(&pkt.data, MAX_FRAME_48K, &mut frame_buf)
            .map_err(|e| {
                tuple(
                    "decode_failed",
                    &format!("failed to decode Opus packet: {e}"),
                )
            })?;
        pcm.extend_from_slice(&frame_buf[..n * channels]);
        if pkt.granule_position != NO_GRANULE {
            final_granule = pkt.granule_position;
        }
    }

    if pcm.is_empty() {
        return Err(tuple(
            "decode_failed",
            "failed to decode Ogg Opus: no audio",
        ));
    }

    let pre_skip = usize::from(head.pre_skip);
    #[allow(clippy::cast_possible_truncation)]
    let total_samples = final_granule.saturating_sub(u64::from(head.pre_skip)) as usize;
    let start = pre_skip.saturating_mul(channels);
    if start > pcm.len() {
        return Err(tuple("decode_failed", "pre_skip exceeds decoded PCM"));
    }
    let mut pcm: Vec<f32> = pcm[start..].to_vec();
    let end = total_samples.saturating_mul(channels).min(pcm.len());
    pcm.truncate(end);

    if head.output_gain_q8 != 0 {
        #[allow(clippy::cast_possible_truncation)]
        let gain = 10f64.powf(f64::from(head.output_gain_q8) / (20.0 * 256.0)) as f32;
        for sample in &mut pcm {
            *sample *= gain;
        }
    }

    if !pcm.len().is_multiple_of(channels) {
        return Err(tuple(
            "invalid_pcm",
            "decoded PCM length is not a multiple of channel count",
        ));
    }
    Ok((pcm, channels))
}

#[allow(clippy::too_many_lines)]
fn encode_ogg_opus(
    pcm: &[f32],
    channels: usize,
    settings: &ReencodeSettings,
) -> Result<Vec<u8>, (String, String)> {
    if channels != 1 && channels != 2 {
        return Err(tuple(
            "invalid_input",
            &format!("unsupported channel count {channels} (need 1 or 2)"),
        ));
    }
    if !pcm.len().is_multiple_of(channels) {
        return Err(tuple(
            "invalid_pcm",
            "decoded PCM length is not a multiple of channel count",
        ));
    }
    if settings.bitrate <= 0 {
        return Err(tuple(
            "invalid_settings",
            "bitrate must be a positive integer",
        ));
    }
    if !(0..=10).contains(&settings.complexity) {
        return Err(tuple(
            "invalid_settings",
            "complexity must be between 0 and 10",
        ));
    }

    let application = parse_application(&settings.application)?;
    let frame_per_ch = frame_samples_48k(settings.frame_duration_ms)?;

    let head = build_opus_head(
        u8::try_from(channels).map_err(|_| tuple("invalid_input", "channel count out of range"))?,
        PRE_SKIP,
    );
    let tags = build_opus_tags();
    let mut out = Vec::new();
    out.extend_from_slice(&write_page(SERIAL, 0, 0, 0x02, &head)?);
    out.extend_from_slice(&write_page(SERIAL, 1, 0, 0x00, &tags)?);

    let per_ch = pcm.len() / channels;
    if per_ch == 0 {
        return Ok(out);
    }

    let mut enc = OpusEncoder::new(48_000, channels, application).map_err(|e| {
        tuple(
            "encode_failed",
            &format!("failed to open Opus encoder: {e}"),
        )
    })?;

    let native = NativeSettings {
        bitrate: Some(settings.bitrate),
        complexity: Some(settings.complexity),
        cbr: Some(settings.cbr),
        fec: None,
        packet_loss: None,
    };
    crate::encoder::apply_settings(&mut enc, &native)
        .map_err(|message| tuple("invalid_settings", &message))?;

    let frame_samples = frame_per_ch * channels;
    let n_frames = per_ch.div_ceil(frame_per_ch);
    let mut packet_buf = vec![0u8; 4000];
    let mut seq = 2u32;
    // Pack like common libopus/ffmpeg muxers: many complete packets per page
    // (≤255 lacing values). One-packet-per-page wastes ~28 B × frame count.
    let mut pending: Vec<Vec<u8>> = Vec::new();
    let mut pending_segments = 0usize;
    let mut pending_granule = u64::from(PRE_SKIP);

    let flush = |out: &mut Vec<u8>,
                 seq: &mut u32,
                 pending: &mut Vec<Vec<u8>>,
                 pending_segments: &mut usize,
                 granule: u64,
                 eos: bool|
     -> Result<(), (String, String)> {
        if pending.is_empty() {
            return Ok(());
        }
        let refs: Vec<&[u8]> = pending.iter().map(Vec::as_slice).collect();
        let htype = if eos { 0x04 } else { 0x00 };
        out.extend_from_slice(&write_page_packets(SERIAL, *seq, granule, htype, &refs)?);
        *seq = seq.wrapping_add(1);
        pending.clear();
        *pending_segments = 0;
        Ok(())
    };

    for f in 0..n_frames {
        let start = f * frame_samples;
        let frame_end = (start + frame_samples).min(pcm.len());
        let mut frame = pcm[start..frame_end].to_vec();
        frame.resize(frame_samples, 0.0);
        let n = enc
            .encode(&frame, frame_per_ch, &mut packet_buf)
            .map_err(|e| {
                tuple(
                    "encode_failed",
                    &format!("failed to encode Opus frame: {e}"),
                )
            })?;
        let pkt = packet_buf[..n].to_vec();
        let segs = segment_count_for_packet(pkt.len());
        let eos = f + 1 == n_frames;
        let page_granule = if eos {
            u64::from(PRE_SKIP) + per_ch as u64
        } else {
            u64::from(PRE_SKIP) + ((f + 1) * frame_per_ch) as u64
        };

        if pending_segments + segs > 255 {
            flush(
                &mut out,
                &mut seq,
                &mut pending,
                &mut pending_segments,
                pending_granule,
                false,
            )?;
        }

        pending.push(pkt);
        pending_segments += segs;
        pending_granule = page_granule;

        if eos {
            flush(
                &mut out,
                &mut seq,
                &mut pending,
                &mut pending_segments,
                pending_granule,
                true,
            )?;
        }
    }
    Ok(out)
}
