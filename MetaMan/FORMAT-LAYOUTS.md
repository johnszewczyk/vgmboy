# MetaMan format layout map

This is a field map of what the current readers actually inspect. Offsets are
zero-based byte positions in the source unless stated otherwise; multibyte
integers include their byte order. A range such as `0x2E..0x4D` is inclusive
here. Chunk-relative offsets are measured from the chunk payload start. This
is not a substitute for each format's full specification, and reserved or
undocumented bytes are retained where the reader can do so safely.

The important distinction is that MetaMan does more than seek to fixed
positions. Some inputs use pointers, length-delimited blocks, repeated chunks,
or event/frame streams. The reader follows those structures with bounds
checks, preserves source bytes, and derives timing without producing audio.

## Reader layouts

### NSF / NESM

NSF has a fixed 128-byte header. Multi-byte addresses and speed fields are
little-endian; the 8-byte strings are decoded up to their first NUL and
trimmed. MetaMan publishes one ordered result entry per declared track and
retains the complete header; it does not read or execute the music program.

| Source position | Meaning |
| --- | --- |
| `0x00..0x04` | `NESM` plus `0x1A` signature. |
| `0x05`, `0x06`, `0x07` | Version, track count, and first-track index. |
| `0x08..0x0D` | Load, init, and play addresses as three little-endian 16-bit values. |
| `0x0E..0x2D`, `0x2E..0x4D`, `0x4E..0x6D` | Game, artist, and copyright/comment fields (32 bytes each). |
| `0x6E..0x6F` | NTSC speed in microseconds per frame. |
| `0x70..0x77` | Eight initial bank values. |
| `0x78..0x79` | PAL speed in microseconds per frame. |
| `0x7A`, `0x7B` | Playback flags and expansion-audio flags. |

### GBS

GBS has a fixed 112-byte header. Addresses are little-endian; the three
32-byte text fields are decoded through their first NUL and trimmed. Each
header-declared track becomes a result entry with its native zero-based source
index. No Game Boy CPU emulation is used to invent per-track titles or timing.

| Source position | Meaning |
| --- | --- |
| `0x00..0x02` | `GBS` signature. |
| `0x03`, `0x04`, `0x05` | Version, track count, and first-track index. |
| `0x06..0x0D` | Load, init, play, and stack addresses as four little-endian 16-bit values. |
| `0x0E`, `0x0F` | Timer modulo and timer control. |
| `0x10..0x2F`, `0x30..0x4F`, `0x50..0x6F` | Game, artist, and copyright/comment fields (32 bytes each). |

### HES / companion extended M3U

HES begins with a fixed `0xD0`-byte header. All multi-byte header integers
below are little-endian. The three text fields begin at `0x40`; each occupies
either `0x20` or `0x30` bytes according to the terminator/extension bytes in
that field. Their order is game, author, copyright. Text is trimmed and
decoded as UTF-8 with Windows-1252 fallback. The full fixed header is retained.

| Source position | Meaning |
| --- | --- |
| `0x00..0x03` | `HESM` signature. |
| `0x04`, `0x05` | HES version and first track. |
| `0x06..0x07` | Init address, little-endian 16-bit. |
| `0x08..0x0F` | Eight bank registers. |
| `0x10..0x13` | Data-chunk identifier (normally `DATA`). |
| `0x14..0x17` | Declared data-chunk size, little-endian 32-bit. |
| `0x18..0x1B` | Data load address, little-endian 32-bit. |
| `0x40` onward | Three variable-width NUL-terminated text fields: game, author, copyright. |

A same-basename `.m3u` is optional support data, not a track. MetaMan's
file-URL convenience reads only that sibling; other clients can supply the
bounded bytes in `MetadataReadContext`. The reader caps the playlist at 4 MiB
and 65,536 parsed rows, rejects NUL bytes and playlists with no usable rows,
and retains the full M3U bytes. UTF-8 is preferred, with Windows-1252 fallback.
Ordered comment tags are retained, including unknown key/value comments.

Each track line maps a path to a source address slot. `$hh` is a hexadecimal
zero-based HES slot; a decimal value is a one-based ordinal (zero retains the
legacy `-1` sentinel). A bare path follows libgme's slot-zero/default row
behavior. Escaped commas in names are unescaped. The parser reads total length,
loop position/body, and fade fields without executing HES code. Positive total
length is authoritative; otherwise a positive intro plus twice the loop body
is used, falling back to 150 seconds. Without M3U, the reader preserves the
256-slot compatibility address space and unknown intro/loop/fade facts; the
ScanSong adapter retains its historical zero-time catalog projection.

See [HESMetadataReader.swift](Sources/MetaManCore/HESMetadataReader.swift).

### KSS / KSCC / KSSX

KSS has a 16-byte base header. Addresses and KSSX numeric extension fields are
little-endian. MetaMan retains the base header and, only when a `KSSX` source
declares an extension size of exactly `0x10` and the complete extension is
present, its 16-byte extension block. It does not parse or emulate the music
payload.

| Source position | Meaning |
| --- | --- |
| `0x00..0x03` | `KSCC` or `KSSX` signature. |
| `0x04..0x05`, `0x06..0x07` | Load address and load size, little-endian 16-bit. |
| `0x08..0x09`, `0x0A..0x0B` | Init and play addresses, little-endian 16-bit. |
| `0x0C`, `0x0D` | First bank and bank-mode bytes. |
| `0x0E`, `0x0F` | Extra-header byte count and device flags. |
| KSSX `0x10..0x13` | Declared payload size, little-endian 32-bit. |
| KSSX `0x14..0x17` | Reserved bytes; preserved in the raw extension block. |
| KSSX `0x18..0x19`, `0x1A..0x1B` | First and last source-track indices, little-endian 16-bit. MetaMan retains `lastTrack + 1` as `declaredTrackCount`. |
| KSSX `0x1C..0x1F` | PSG, SCC, MSX Music, and MSX Audio volume bytes. |

For catalog compatibility, the ordered result continues to expose the same 256
info-only slots and 150-second play-length fallback as ScanSong and the
installed libgme 0.6.5 oracle, even when the KSSX extension declares a smaller
track range. The extension range remains visible as source facts instead of
being silently promoted to a new catalog track count. MetaMan's normalized
system field preserves ScanSong's established device-flag labels, leaving the
scanner to adapt the shared document without reinterpreting the header. KSS M3U
sidecars are not consumed. See
[KSSMetadataReader.swift](Sources/MetaManCore/KSSMetadataReader.swift).

### Sony CD-XA sectors

MetaMan reads XA sector structure and timing without decoding the ADPCM
payload. Raw sectors are 0x930 (2352) bytes; the accepted RIFF/CDXA wrapper
places the first raw sector at absolute offset 0x2C. The source must identify
one of those containers, and raw input receives vgmstream-compatible frame
sanity checks before the ordered sector walk.

| Source position | Meaning |
| --- | --- |
| Raw sector +0x00..+0x0B | Raw-sector sync: 00 FF FF FF FF FF FF FF FF FF FF 00; not required inside RIFF/CDXA. |
| Raw sector +0x10..+0x13 | First four-byte subheader: file number, channel number, submode, coding info. All sector metadata is read from this copy. |
| Raw sector +0x14..+0x17 | Duplicate subheader copy; retained in the source but not used for metadata selection. |
| Raw sector +0x18..+0x917 | 0x900-byte sector payload. For raw input, its 18 0x80-byte audio frames are probed in the first three audio sectors; ADPCM samples are not decoded. |
| Raw sector +0x918..+0x92F | Trailing sector bytes; not part of the sample-count calculation. |
| RIFF 0x00..0x03, 0x08..0x0B, 0x0C..0x0F | RIFF, CDXA, and fmt signature checks. The current metadata route begins sector walking at 0x2C; it does not parse RIFF chunk lengths. |

Submode bit 0x04 marks audio, while bits 0x08 and 0x02 exclude data
and Form-2-video sectors from the audio walk. Bit 0x80 marks per-channel end
of track and resets that channel's state. File/channel pairs are tracked
independently across at most 128 channel slots; the scanner-compatible visible
subsong cap is 1,000. When there are multiple subsongs, the title is the
four-digit hexadecimal file/channel pair; a single subsong uses the filename
without its extension.

Coding-info bits 0..1 select mono/stereo, bits 2..3 select 37,800/18,900 Hz,
and bits 4..5 select 4/8-bit samples. Unsupported codes and 8-bit mono fail.
Form-2 submode bit 0x20 selects 18 XA frames per sector instead of 16.
Samples per sector are (28 * subframes / channels) * formFrames, where
subframes is 8 for 4-bit or 4 for 8-bit audio. Play time is the accumulated
audio-sector count times samples per sector divided by sample rate. Source facts
retain this calculation's configuration and counts on each track.

The first three raw audio sectors validate duplicated frame-header bytes,
predictor/shift ranges, and a nonblank first frame. Before the first audio
sector, at most 32 non-audio sectors are skipped. A 100-byte first raw sector
prefix remains accepted when the available header/frame bytes pass the same
legacy probe; out-of-range frame bytes are zero-filled. The reader folds
vgmstream's modulo-32-bit sparse-file probe after EOF rather than revisiting
the same sector headers indefinitely. Unrecognized .xa aliases remain
outside this parser and are routed by ScanSong to vgmstream.

See [SonyXAMetadataReader.swift](Sources/MetaManCore/SonyXAMetadataReader.swift).

### NSFE

NSFE starts with `NSFE`; chunks then repeat as a little-endian 32-bit payload
length, four-byte identifier, and payload. Chunk identifiers are case-sensitive.
The reader bounds-checks every chunk, requires `INFO`, `DATA`, and `NEND` in
valid order, validates playlist references, and counts but neither copies nor
decodes the audio `DATA` payload. The ordered MetaMan result applies `PLST`
(including repeated source indices); absent/empty `PLST` means source order.

| Chunk | Payload interpretation |
| --- | --- |
| `INFO` | Minimum 8 bytes: little-endian load/init/play addresses at `+0..+5`, region and expansion flags at `+6` and `+7`; optional track count at `+8` (default 1), first-track index at `+9` (default 0). |
| `DATA` | Audio payload; validated and counted, never parsed as metadata or decoded. |
| `NEND` | Ends the file walk after required `INFO` and `DATA`. |
| `auth` | NUL-separated game, artist, copyright, and ripper strings. |
| `tlbl`, `taut` | NUL-separated source-track labels and per-track authors. |
| `time`, `fade` | Signed little-endian 32-bit millisecond arrays in source-track order; partial trailing bytes are diagnosed and ignored. Positive `time` is finite play length; absent/nonpositive time keeps the 150-second scanner fallback. Nonnegative fade values are retained. |
| `plst`, `psfx` | Byte arrays of source-track indices; `plst` determines visible order and may repeat tracks, `psfx` marks sound-effect tracks. |
| `BANK`, `RATE`, `regn`, `NSF2`, `VRC7` | Bank bytes; NTSC/PAL/Dendy speed values; region override/preference; NSF2 flags; VRC7 variant and optional patch bytes. |
| `text` | NUL-separated notes; the first string contributes to the scanner comment. |
| Other lowercase-leading IDs | Optional chunks. Their complete framed bytes are retained in the non-audio raw block. Unknown uppercase-leading IDs are unsupported mandatory chunks and fail. |

The NSFE raw metadata block keeps the `NSFE` signature and all non-`DATA`
chunk frames in source order. Each track document also exposes native source
index, visible index, timing, playlist, hardware, and payload-size facts.
See [GameMusicMetadataReader.swift](Sources/MetaManCore/GameMusicMetadataReader.swift).

### Nintendo DS STRM

The reader accepts a bounded Nintendo DS STRM container signature, validates
its `HEAD` chunk and the following `DATA` chunk header, and never decodes the
sample payload. Header and chunk integers are little-endian except for the
four-byte byte-order marker, which is compared in big-endian display order.

| Source position | Meaning |
| --- | --- |
| `0x00..0x03` | `STRM` signature. |
| `0x04..0x07` | Byte-order marker: `0xFFFE0001` or `0xFEFF0001`. |
| `0x08..0x0B` | Declared file size, little-endian 32-bit. |
| `0x0C..0x0D`, `0x0E..0x0F` | Declared header size and block count, little-endian 16-bit. |
| `0x10..0x13` | `HEAD` chunk identifier. |
| `0x14..0x17` | `HEAD` chunk size; the supported layout is `0x50`. |
| `0x18`, `0x19`, `0x1A` | Codec (`0` PCM8, `1` PCM16LE, `2` Nintendo DS IMA ADPCM), loop-enabled flag, and channel count (1 or 2). |
| `0x1C..0x1D` | Sample rate in Hz, little-endian 16-bit. |
| `0x20..0x23`, `0x24..0x27` | Loop-start sample and total sample count, little-endian 32-bit. |
| `0x28..0x2B` | Sample-data offset from file start, little-endian 32-bit; must point after the `DATA` chunk header and within the source. |
| `0x30..0x33`, `0x38..0x3B` | Interleave block size and final interleave-block size, little-endian 32-bit. |
| `0x60..0x63`, `0x64..0x67` | `DATA` identifier and declared chunk size. The sample payload normally begins at `0x68`; the header's data offset is authoritative. |

The preserved raw blocks are the complete fixed `0x60`-byte STRM/HEAD header
and the eight-byte DATA chunk header. Timing uses integer sample arithmetic
and floors to milliseconds: loop length is zero when looping is disabled, or
`max(0, samples - loopStart) / rate` when enabled; finite play length is
`samples / rate`. For looped tracks, the legacy
vgmstream info projection is retained: `loopStart + 2 * loopLength + 10 *
rate` frames before conversion to milliseconds. The loop-enabled flag controls
both whether loop duration is exposed and whether the extended play-window
formula is applied. Other formats sharing `.strm` remain outside this reader. See
[NDSSTRMMetadataReader.swift](Sources/MetaManCore/NDSSTRMMetadataReader.swift).

### Nintendo DS FFTA2 RIFF/IMA

Final Fantasy Tactics A2 uses a separate Square Enix stream container. The
signature is `RIFF` at byte zero and `IMA ` at `0x08`; unlike ordinary RIFF,
the little-endian size at `0x04` equals the complete file size. The content
probe requires that declared size to equal the physical file length.

| Source position | Meaning |
| --- | --- |
| `0x00..0x03` | `RIFF` signature. |
| `0x04..0x07` | Complete file size, little-endian 32-bit; the reader uses `size - 0x2C` as the decoder-compatible sample count. |
| `0x08..0x0B` | `IMA ` codec marker. |
| `0x0C..0x0F` | Sample rate in Hz, little-endian 32-bit. |
| `0x20..0x23` | Loop-start sample; nonzero enables looping. |
| `0x24..0x27` | Channel count, little-endian 32-bit (validated as 1 or 2). |
| `0x28..0x2B` | Loop-end sample, little-endian 32-bit. |
| `0x2C...` | Interleaved IMA sample payload; the legacy layout uses `0x80`-byte interleave blocks. Payload bytes are not decoded or retained. |

The exact `0x2C`-byte header is retained as a raw metadata block. Loop length
is zero when the loop-start field is zero; otherwise it is
`(loopEnd - loopStart) / rate`. A looped play window is
`loopStart + 2 * loopLength + 10 * rate` frames, matching the former
vgmstream scanner projection. Non-looped play length is `sampleCount / rate`.
The normalized title is the filename without its extension and the metadata
source is `Square Enix RIFF IMA header`. See
[NDSSTRMMetadataReader.swift](Sources/MetaManCore/NDSSTRMMetadataReader.swift).

### Nintendo DSPADPCM, Retro Studios RS03, and THP audio

These are three unrelated `.dsp` layouts. ScanSong dispatches by content; the
extension-only route remains vgmstream, and unrecognized `.dsp` payloads keep
that decoder fallback.

#### Standard Nintendo DSPADPCM

The standard stream has a big-endian `0x60`-byte header followed by mono
DSPADPCM data. It has no magic, so recognition validates the header and checks
that the first audio frame's predictor/scale byte agrees with the header. A
matching second header at `0x60` or `0x10000` is not claimed as standard mono.

| Source position | Meaning |
| --- | --- |
| `0x00..0x03`, `0x04..0x07`, `0x08..0x0B` | Sample count, nibble count, and rate (big-endian 32-bit). |
| `0x0C..0x0D`, `0x0E..0x0F` | Loop flag (`0` or `1`) and codec format (`0`), big-endian 16-bit. |
| `0x10..0x13`, `0x14..0x17`, `0x18..0x1B` | Loop-start nibble, loop-end nibble, and initial nibble offset. |
| `0x1C..0x3B` | Sixteen big-endian signed ADPCM coefficients. |
| `0x3C..0x3D` | Gain. |
| `0x3E..0x3F`, `0x40..0x43` | Initial predictor/scale and two initial history samples. |
| `0x44..0x49` | Loop predictor/scale and two loop history samples. |
| `0x4A..0x4D` | Optional channel and block-size hints from DSPADPCM tool variants. |
| `0x60...` | Encoded audio; never decoded or retained. |

Nibble positions map to samples as `floor(nibbles / 16) * 14` when the
remainder is zero, or `floor(nibbles / 16) * 14 + remainder - 2` otherwise;
the calculation is signed because remainder `1` maps to `-1`. The decoder's
inclusive loop end adds one sample and clamps to the declared sample count. ScanSong keeps its established
projection (`intro=0`, loop span from native loop samples, and the vgmstream
two-repeat/10-second-fade play window for looped sources). The raw header and
native offsets remain available in the MetaMan document.

#### Retro Studios RS03

The decoder calls this Metroid Prime 2 layout `RS03`; its four signature bytes
are `52 53 00 03` (`0x52530003`), not ASCII `RS03`. It begins with a `0x60`-byte
big-endian header and `0x8F00`-byte audio interleave blocks.

| Source position | Meaning |
| --- | --- |
| `0x00..0x03` | Magic value `0x52530003` (bytes `52 53 00 03`). |
| `0x04..0x07`, `0x08..0x0B`, `0x0C..0x0F` | Channel count, total samples, and sample rate (big-endian 32-bit). |
| `0x14..0x15` | Loop flag (big-endian 16-bit). |
| `0x18..0x1B`, `0x1C..0x1F` | Loop-start and loop-end byte offsets. Each maps to `floor(bytes / 8) * 14` samples. |
| `0x20..0x5F` | Sixteen big-endian coefficients per channel, spaced `0x20` bytes apart. |
| `0x60...` | Interleaved encoded DSP audio; never decoded or retained. |

Loop and play timing use the native sample rate and loop bounds with the same
scanner-compatible two-repeat/10-second-fade policy as the standard DSP
reader. The full fixed header and raw byte offsets are preserved.

#### Nintendo THP audio component

THP is a movie container, not a DSP-header alias. The reader accepts `.thp`
files and the same content under `.dsp`, for versions 1.0 and 1.1. It follows
the bounded component table to the audio component and reads the same
channel/rate/sample fields used by the vgmstream info path. It does not walk
or decode movie blocks.

| Source position | Meaning |
| --- | --- |
| `0x00..0x03`, `0x04..0x07` | `THP\0` signature and version (`0x00010000` or `0x00011000`; byte order follows the version word). |
| `0x08..0x0F` | Maximum buffer and maximum audio sizes. |
| `0x14..0x1F` | Block count, first-block size, and declared data size. |
| `0x20..0x23` | File offset of the component descriptor table. |
| `0x28..0x2B` | First audio block offset. |
| Component type table | Component count, then a fixed 16-byte type array (`0` video, `1` audio). |
| Component headers | Video headers before audio: width/height in v1.0, plus a format word in v1.1. |
| Audio component header | Audio channel count, sample rate, and sample count; v1.1 adds a format word. |

If the component-table pointer at `0x20` is `T`, the component count is at
`T`, the fixed type array begins at `T + 4`, and component headers begin at
`T + 0x14`. The audio-header position is that header start plus the sizes of
the preceding video headers (`8` bytes in v1.0, `12` in v1.1). The audio
header is `12` bytes in v1.0 and `16` in v1.1; its first three 32-bit values
are channels, sample rate, and sample count.

No loop is declared by this THP info layout; play time is sample count divided
by rate. The file header, component types, intervening component headers, and
audio header are retained as separate raw metadata blocks. See
[NintendoDSPMetadataReader.swift](Sources/MetaManCore/NintendoDSPMetadataReader.swift)
and the decoder-reference layouts in
[`ngc_dsp_std.c`](../VGMBoy/vendor/vgmstream/src/meta/ngc_dsp_std.c),
[`rs03.c`](../VGMBoy/vendor/vgmstream/src/meta/rs03.c), and
[`thp.c`](../VGMBoy/vendor/vgmstream/src/meta/thp.c).

### Retro Studios AGSC banks

AGSC has two chunk organizations. Version 1 begins with a bounded NUL string
(normally `Audio/`), followed by the bank-name string. Version 2 begins with a
big-endian `1`, then its bank name and a two-byte song identifier. The decoder
uses the bank name as the visible stream name in both versions. Strings follow
vgmstream's 0x20-byte reader limit; a full-width field consumes the extra byte
between fields even if it is not NUL-terminated.

| Position | Meaning |
| --- | --- |
| v1 `0x00` | First string, normally `Audio/`; its first four bytes are the `Audi` version-1 signature. |
| v1 after first string | Bank/stream name, read with the same 0x20-byte bound. |
| v1 after name | Two consecutive chunks, each `u32BE size` followed by that many opaque bytes. |
| v1 after unknown chunks | Audio chunk: `u32BE data size`, then encoded audio bytes. The following header chunk is `u32BE header size` plus header bytes. |
| v2 `0x00..0x03` | `u32BE(1)` version marker. |
| v2 `0x04` | Bank/stream name, followed by its two-byte song id. |
| v2 after song id | Four `u32BE` sizes in order: unknown chunk 1, unknown chunk 2, header, audio data. Their chunk bodies follow in that same order. |
| Header chunk `+0x00..0x1F`, per stream | `+0x00` id; `+0x04` encoded-stream offset relative to audio data; `+0x08` unknown; `+0x0C` mixer value (commonly `0x3C00`); `+0x0E` sample rate (`u16BE`); `+0x10` sample count (`s32BE`); `+0x14` loop start (`s32BE`); `+0x18` loop length (`s32BE`); `+0x1C` coefficient offset (`s32BE`). |
| Header chunk after stream records | A four-byte `0xFFFFFFFF` marker, followed by one 0x28-byte DSP coefficient block per stream. Stream count follows vgmstream's formula `(headerSize - 4) / (0x20 + 0x28)`. |

Version 1 stores audio before the header chunk; version 2 stores header before
audio. The reader bounds-checks both chunk layouts, the encoded extent derived
from `sampleCount / 14 * 8`, each loop and coefficient range, and caps
enumeration at 1,000 rows. Per-track title is the bank name; channel count is
mono as declared by vgmstream's AGSC initializer. A nonzero loop length is
projected as `loopStart + loopLength - 1` (vgmstream's inclusive loop end);
loop duration uses the same `end - start` sample count as ScanSong's `-I`
adapter. For looped files the scanner play-time projection is
`loopStart + 2 * (loopEnd - loopStart) + 10 seconds`; unlooped files use the
native sample count. This retains vgmstream's play duration without emulating
or decoding audio. Coefficient pointers are based at `headerOffset + 8` and are
bounds-checked against the complete source file. The live Retro Studios bank
uses a coefficient range that extends eight bytes beyond the declared header
chunk, so chunk-local bounds would reject valid content. The raw name, each
stream record, its coefficient block, and both opaque chunks are retained per
result entry.

See [AGSCMetadataReader.swift](Sources/MetaManCore/AGSCMetadataReader.swift).

### vgmstream GENH generic headers

GENH is a small generic wrapper around otherwise headerless or externally
described streams. The fixed header is little-endian and begins with `GENH`.
MetaMan reads the header fields and never opens the codec named by the header.
The decoder reference is
[`genh.c`](../VGMBoy/vendor/vgmstream/src/meta/genh.c).

| Offset | Width | Meaning |
| --- | ---: | --- |
| `0x00` | 4 | ASCII `GENH` signature. |
| `0x04` | 4 | Channel count, signed 32-bit interpretation. |
| `0x08` | 4 | Interleave size in bytes. |
| `0x0C` | 4 | Sample rate, signed 32-bit interpretation. |
| `0x10` | 4 | Loop-start sample, signed 32-bit; `-1` is the usual no-loop marker. |
| `0x14` | 4 | Loop-end sample, signed 32-bit. |
| `0x18` | 4 | Codec ID: 0 PS-ADPCM, 1 Xbox IMA, 2 GameCube DTK, 3/4 PCM16 BE/LE, 5 PCM8, 6 SDX2, 7 DVI IMA, 8 MPEG, 9 IMA, 10 AICA, 11 MS ADPCM, 12 Nintendo DSP, 13 interleaved unsigned PCM8, 14 PS-ADPCM bad-flags, 15 Microsoft IMA, 16 unsigned PCM8, 17 Apple IMA4, 18/19 ATRAC3/ATRAC3+, 20/21 XMA1/XMA2, 22 FFmpeg format, 23 AC-3, 24 PC-FX ADPCM, 25/26 signed/unsigned PCM4, 27 OKI16, 28 AAC. |
| `0x1C` | 4 | Audio-data start offset. |
| `0x20` | 4 | Declared header size. Must be at least `0x24` and no greater than the audio offset. |
| `0x24` | 4 | Optional DSP coefficient base when header size is at least `0x30`. |
| `0x28` | 4 | Optional DSP coefficient spacing for more than two channels; for stereo, the decoder interprets this as the right-channel coefficient base and derives spacing. |
| `0x2C` | 4 | Optional DSP coefficient interleave type. |
| `0x30` | 4 | Optional coefficient flags when header size is at least `0x34`: bit 0 selects split coefficient arrays; bit 1 selects little-endian coefficients (otherwise big-endian). |
| `0x34`, `0x38` | 4 each | Optional second DSP coefficient base and spacing/right-channel base when header size is at least `0x3C`. |
| `0x40` | 4 | Optional signed sample count when header size is at least `0x100`; if not positive, vgmstream falls back to the loop-end field at `0x14`. |
| `0x44` | 4 | Optional signed encoder skip-sample count. |
| `0x48` | 1 | Optional skip-sample mode (`0` auto, `1` force the value at `0x44`). |
| `0x49` | 1 | Optional ATRAC3/ATRAC3+ codec-mode fallback when `0x4B` is zero. |
| `0x4A` | 1 | Optional XMA1/XMA2 codec-mode fallback when `0x4B` is zero. |
| `0x4B` | 1 | Optional primary codec-mode byte. |
| `0x50` | 4 | Optional data-byte count; zero means bytes from audio offset to end of file. |
| `0x54` | 4 | Optional final interleave size. |

The legacy compatibility case is exact: when `0x20` is zero, vgmstream
replaces both the declared header size and audio offset with `0x800`; MetaMan
does the same and preserves those `0x800` source bytes. For ordinary headers,
the raw block extends from file offset zero through the declared header size.
For sample timing, a positive extended sample count wins, otherwise the
signed loop-end value is used. A valid loop uses `loopEnd - loopStart`
samples; the scanner-compatible looped play projection is
`loopStart + 2 * loopLength + 10 * sampleRate` samples. Non-looped play time
uses the selected sample count. Milliseconds are integer-truncated sample
counts divided by the declared rate. The filename stem supplies the title;
the comment/source label is `GENH generic header`.

GENH is one stream per file. Its generic header does not contain an internal
game/song tag or enumerate tracks; it only describes the payload's codec and
layout. MetaMan exposes codec/layout facts, optional DSP and encoder fields,
source bytes, and timing without loading the audio decoder. A suffix alias
whose signature or header is invalid remains eligible for vgmstream fallback.
See [GENHMetadataReader.swift](Sources/MetaManCore/GENHMetadataReader.swift).

### AY / ZXAYEMUL

| Source position | Meaning |
| --- | --- |
| `0x00..0x07` | `ZXAYEMUL` signature; fixed header ends at `0x14`. |
| `0x08`, `0x09` | Version and player ID bytes. |
| `0x0C..0x0D`, `0x0E..0x0F` | Signed big-endian 16-bit relative pointers to NUL-terminated author and comment text; each displacement is based at its own pointer word. |
| `0x10` (decimal 16), `0x11` (17) | Maximum track index and first-track byte. The parser enumerates `maximumTrack + 1` source slots in table order. |
| `0x12..0x13` (18..19) | Signed relative pointer to a table of four-byte entries. Entry `n` is at `table + 4*n`. |
| Each entry `+0..+1`, `+2..+3` | Signed big-endian relative pointers, based at each pointer word, to the title string and six-byte track-info record. |
| Track info `+4..+5` | Big-endian 50 Hz frame count; positive values become milliseconds at 20 ms/frame. Zero/missing retains the established 150-second info-only default. |

Text pointers are bounded and decoded with the former ScanSong trimming and
placeholder rules. The parser retains the fixed header, table, and referenced
text/info blocks. See [AYMetadataReader.swift](Sources/MetaManCore/AYMetadataReader.swift).

### SAP

SAP has no fixed-position metadata record. The file begins `SAP\r\n`, then
CR/LF-terminated ASCII directive names and values, and ends its information
header at the first `FF FF` data marker. MetaMan caps this header at 1 MiB and
retains its exact bytes. Directive order matters for repeated `TIME` lines:
the first applies to source track 0, the next to track 1, and so on.

| Directive | Interpretation |
| --- | --- |
| `SONGS n` | Track count; default is one. |
| `TYPE B` / `TYPE C` | Accepted player type, retained as a source fact. |
| `INIT`, `PLAYER`, `MUSIC` | Four-hex-digit Atari addresses. |
| `FASTPLAY n`, `STEREO` | Playback setup facts; no emulation is needed to read them. |
| `NAME`, `AUTHOR`, `DATE` | Quoted game, author, and date/copyright text. |
| `TIME mm:ss[.fraction] [LOOP]` | Ordered per-track hint. A `LOOP` value is the loop start; otherwise it is a finite length. Fractions of one, two, or three digits scale to milliseconds. |
| Other directives | Kept in ordered decoded tags and the raw header even if MetaMan has no normalized field for them. |

See [SAPMetadataReader.swift](Sources/MetaManCore/SAPMetadataReader.swift).

### SNDH / Atari ST

SNDH is executable 68000 music data. MetaMan inspects only its bounded header
and tag area; it never follows an executable vector or enters the music
routines. Header integers and pointers below are big-endian.

| Source position / tag | Meaning |
| --- | --- |
| `0x00`, `0x04`, `0x08` | Three executable-vector branch slots. The reader recognizes short `BRA`, word `BRA`, and PC-relative `JMP` forms and uses the smallest valid in-file target as the tag-area bound. |
| `0x0C..0x0F` | ASCII `SNDH` marker. |
| `0x10...` | Ordered tag block. Parsing stops at `HDNS` or the executable-vector bound; the consumed bytes, including `HDNS` when present, are retained. |
| `TITL`, `COMM`, `RIPP`, `CONV`, `YEAR` | NUL-terminated Atari ST text. Normalized title/artist/year come from `TITL`/`COMM`/`YEAR`; all recognized tags remain ordered. |
| `TA`, `TB`, `TC`, `TD`, `!V` | NUL-terminated decimal timer rates. The first encountered timer tag supplies `FRMS` timing; a missing or zero rate defaults to 50 Hz. |
| `##` | Two ASCII decimal digits declaring subtune count. The reader validates a positive count and caps it at 10,000. |
| `!#` | NUL-terminated decimal, one-based default subtune. Out-of-range values normalize to subtune 1. |
| `!#SN`, `FLAG` | One big-endian 16-bit relative offset per subtune, based at the tag's first byte, followed by bounded NUL-terminated Atari ST strings. Table targets must land beyond the pointer table. |
| `TIME` | One big-endian 16-bit seconds value per subtune. Used when no corresponding `FRMS` entry exists. |
| `FRMS` | One big-endian 32-bit frame count per subtune. Duration is rounded from `frames / timer-rate` to milliseconds. |
| `FLAG~` | One NUL-terminated Atari ST text value; retained as an ordered tag. |
| `ICE!` wrapper `0x00..0x0B` | ICE signature, big-endian packed size at `0x04`, and expanded size at `0x08`. The reverse-bitstream expander validates both lengths and caps output at 256 MiB before the SNDH header walk. |

Outer `.zst` library wrappers are transport and are materialized by ScanSong
before the `.sndh` member reaches MetaMan. `ICE!` is a distinct inner wrapper
handled by MetaMan itself. See
[SNDHMetadataReader.swift](Sources/MetaManCore/SNDHMetadataReader.swift) and
[ICEMetadataDecompressor.swift](Sources/MetaManCore/ICEMetadataDecompressor.swift).

### S98 v0-v3

The first `0x20` bytes contain the fixed header. All listed integers are
little-endian 32-bit values; header offsets are absolute file positions.

| Header position | Meaning |
| --- | --- |
| `0x00..0x03` | `S980` through `S983` signature/version. |
| `0x04..0x07`, `0x08..0x0B` | Tick numerator and denominator. Zero/default values are normalized per version. |
| `0x10..0x13` | Tag block offset; v0-v2 tags are legacy NUL-terminated text, v3 begins with `[S98]`. |
| `0x14..0x17` | Command-stream start offset. |
| `0x18..0x1B` | Loop command offset. It must land on a valid event before the stream terminator. |
| `0x1C..0x1F` | v3 device count. v2 instead has 16-byte device entries at `0x20` ending in a zero-type entry; v3 entries start at `0x20`. |

The command stream is a variable-length walk, not a fixed-offset lookup:
`FF` advances one tick, `FE` reads a variable-length delta and advances
`delta + 2`, `FD` ends timing, and other commands consume a two-byte register
write. The tag offset, when it lies after the stream start, bounds the stream.
Timing is converted by `ticks * numerator / denominator`. See
[S98MetadataReader.swift](Sources/MetaManCore/S98MetadataReader.swift).

### VGM / VGZ

VGM's standard header is 64 bytes; its fixed integers are little-endian.

| Header position | Meaning |
| --- | --- |
| `0x00..0x03` | `Vgm ` signature. |
| `0x04..0x07`, `0x08..0x0B` | Stored EOF displacement (relative to `0x04`) and version. |
| `0x14..0x17` | GD3 relative pointer; nonzero offsets are based at `0x14`. |
| `0x18..0x1B`, `0x1C..0x1F`, `0x20..0x23` | Total samples, loop-relative pointer (based at `0x1C`), and loop sample count. |
| `0x34..0x37` | v1.50+ data-relative pointer, based at `0x34`; zero/older-version uses `0x40`. |

GD3 begins at `0x14 + pointer`: `Gd3 `, 32-bit version, 32-bit payload byte
count, then NUL-terminated UTF-16LE strings. The standard ordered sequence has
11 values; extra values are retained. VGZ first inflates through a bounded
gzip path. Timing uses the 44.1 kHz sample counts. See
[VGMMetadataReader.swift](Sources/MetaManCore/VGMMetadataReader.swift).

### PSF / PSF2 / SSF / USF / 2SF tag family

The 16-byte common header has a three-byte `PSF` signature plus format version
at `0x00..0x03`; little-endian reserved byte count at `0x04..0x07`, compressed
payload byte count at `0x08..0x0B`, and CRC at `0x0C..0x0F`. The tag location is
computed as `0x10 + reservedSize + compressedSize`, not found at a fixed EOF
offset. If `[TAG]` is present there, the remaining text is parsed as ordered
`key=value` lines. `length` and `fade` supply timing. The compressed program
body is deliberately not interpreted by this metadata reader. See
[PSFMetadataReader.swift](Sources/MetaManCore/PSFMetadataReader.swift).

### GSF / miniGSF / PSF v0x22

GSF uses the 16-byte PSF v0x22 container header described above. All integers
are little-endian. The reader bounds the reserved and compressed regions,
checks CRC-32 over exactly the compressed bytes, then inflates the executable.
The `[TAG]` marker is accepted only at
`0x10 + reservedSize + compressedSize`; the tag bytes through EOF are retained
verbatim, while the NUL-terminated UTF-8 view preserves source order, repeated
names, and unknown keys.

| Source position | Meaning |
| --- | --- |
| `0x00..0x03` | `PSF` plus version `0x22`. |
| `0x04..0x07` | Reserved-region byte count. |
| `0x08..0x0B` | Compressed executable byte count. |
| `0x0C..0x0F` | CRC-32 of the compressed executable region. |
| `0x10..` | Reserved bytes followed by the zlib-compressed GSF executable. |
| `0x10 + reservedSize + compressedSize` | Optional `[TAG]` marker, then original tag bytes. |

The inflated executable begins with a 12-byte segment header. Bytes `0x00..03`
are included in the executable and size accounting; bytes `0x04..07` provide
the little-endian load offset masked with `0x01FFFFFF`; bytes `0x08..0B`
declare the segment's image span. Bytes `0x0C..EOF` are placed at that offset
in the assembled GBA image. Declared but absent tails are treated as unknown,
not trusted zeroes. Load order is `_lib` before the current segment, then
contiguous `_lib2`, `_lib3`, and later references until the first gap. Each
library's own `_lib` is visited before its executable segment. This is why a
footer-only PSF reader is not a complete GSF reader.

Recognition needs only assembled ROM bytes `0x00..0xB2`. Byte `0x03` must be
`0xEA`; byte `0xB2` is the standard `0x96` signature, with the legacy fallback
allowed only when `0x04..0x9F` are all zero. The seven ARM exception vectors
are also checked to reject a BIOS image. These checks mirror mGBA's image
admission without running the core. The reader retains every source's exact
16-byte PSF header and raw tag block, plus path, CRC, reserved/compressed sizes,
segment offset/declared size, inflated length, and final image size as facts.

The file-URL entry point opens only explicitly referenced relative library
paths, rejects traversal and symlink escapes, and applies 128 MiB per-container,
512 MiB aggregate, 256-file, depth-10, 64 MiB inflated-segment, and 64 MiB
assembled-image limits. Data-based reads instead require named library bytes
in `MetadataReadContext`. Root `length`/`fade` values and dependency fallback
retain the previous catalog projection, including the legacy nested-length
intro value. See [GSFMetadataReader.swift](Sources/MetaManCore/GSFMetadataReader.swift).

### QSF / miniQSF / PSF v0x41

QSF uses the common 16-byte PSF container header, with version `0x41` required
for the playable root. The reader checks declared ranges and CRC-32 over only
the compressed region, inflates it with a 32 MiB + 12-byte bound, then walks
the decompressed QSound data blocks. `[TAG]` is accepted only at the exact end
of the reserved and compressed regions. The complete root tag block and each
container's 16-byte header, reserved bytes, and tag block are retained; the
compressed program/audio payload is structurally inspected but not copied into
the metadata result.

| Source position | Meaning |
| --- | --- |
| `0x00..0x02` | ASCII `PSF` signature. |
| `0x03` | Root version `0x41`; QSFLib dependencies require the `PSF` signature but retain the former reader's permissive version check. |
| `0x04..0x07` | Reserved-region byte count, little-endian 32-bit. |
| `0x08..0x0B` | Compressed QSound program byte count, little-endian 32-bit. |
| `0x0C..0x0F` | CRC-32 of the compressed region, little-endian 32-bit. |
| `0x10..0x10+reservedSize-1` | Reserved bytes. The following `compressedSize` bytes contain the zlib stream. |
| `0x10 + reservedSize + compressedSize` | Optional `[TAG]` marker; the exact marker and following bytes through EOF are retained. |

The inflated QSF body is a sequential series of data blocks. Each block starts
with an 11-byte header followed by the declared payload; no decoder is started.

| Block-relative position | Meaning |
| --- | --- |
| `+0` | Kind byte: `0x5A` (`Z`) Z80 program ROM, `0x53` (`S`) QSound sample ROM, `0x4B` (`K`) Kabuki decryption keys; other kinds remain playback-loader-ignored. |
| `+1..+2` | Legacy block header bytes not interpreted by the metadata reader. |
| `+3..+6` | Destination offset in the target ROM/key space, little-endian 32-bit. |
| `+7..+10` | Payload byte count, little-endian 32-bit. |
| `+11..+11+length-1` | Block data. |

The reader requires each declared payload to fit the inflated source and each
destination range to avoid integer overflow. Z80 ranges may end at or before
512 KiB; sample-ROM ranges may end at or before 8 MiB; key blocks must contain
at least 11 bytes. Unknown block kinds are accepted without imposing a format
rule the playback loader does not enforce. The ordered tag view is UTF-8,
stops at the first NUL, preserves duplicate/unknown entries, and is bounded to
4 MiB. Field lookup is case-insensitive and last-value-wins to match the old
ScanSong projection. `length` and `fade` use the QSound bridge's
`minutes:seconds`/numeric-prefix parsing and 44.1 kHz frame quantization.

The root's `_lib`, `_lib2`, ... `_lib9` entries are checked in numeric load
order. Those direct QSFLib containers have the same CRC, zlib, block-bound, and
tag validation; their metadata does not override the root, and their own
library references are not followed. File-URL reads resolve only these
relative siblings, reject traversal and symlink escapes, cap each container at
64 MiB and aggregate dependency bytes at 512 MiB. Data-based reads require the
caller to provide named companions in `MetadataReadContext`. The document
keeps root authored fields/timing and reports source paths, sizes, CRCs, and
block kind/offset/length facts. See
[QSFMetadataReader.swift](Sources/MetaManCore/QSFMetadataReader.swift).

### SPC / ID666 / xID6

The standard file body ends at `0x10200`; the 27-byte `SNES-SPC700 Sound File
Data` signature begins at zero. ID666 is a fixed area, and its binary/text
layouts shift a few fields by one byte.

| Source position | Meaning |
| --- | --- |
| `0x23` | ID666 presence/layout flag. MetaMan can recover coherent fixed-slot data even if the flag says absent. |
| `0x2E..0x4D` | Song, 32 bytes. |
| `0x4E..0x6D` | Game, 32 bytes. |
| `0x6E..0x7D` | Dumper, 16 bytes. |
| `0x7E..0x9D` | Comment, 32 bytes. |
| `0x9E..0xA8` | Text date (11 bytes); binary layout reads its compact date at `0x9E..0xA1`. |
| `0xA9..0xAB` | Text seconds or binary little-endian play seconds. |
| `0xAC..0xB0` | Text milliseconds or binary little-endian 24-bit fade. |
| `0xB0..0xCF` / `0xB1..0xD0` | 32-byte artist slot in binary/text layouts. |
| `0xD0`/`0xD1`, `0xD1`/`0xD2` | Muted-voice and emulator bytes; first offset is binary layout, second is text layout. |

An optional `xid6` chunk begins exactly at `0x10200`: four-byte signature,
little-endian 32-bit payload length, then four-byte item headers (`id`, `type`,
little-endian 16-bit length/value) and aligned payloads. Recognized item IDs
include identity (`01..07`), soundtrack/publisher (`10..14`), timing
(`30..33`), and playback hints (`34..36`). Full ID666/xID6 blocks are retained.
See [SPCMetadataReader.swift](Sources/MetaManCore/SPCMetadataReader.swift).

### SID / PSID / RSID

The fixed fields use big-endian integers. `PSID`/`RSID` is at `0x00`, version
at `0x04`, and v1 header length is `0x76`; v2+ is `0x7C`.

| Header position | Meaning |
| --- | --- |
| `0x06..0x07`, `0x08..0x09`, `0x0A..0x0B`, `0x0C..0x0D` | Data offset, load address, init address, play address. |
| `0x0E..0x0F`, `0x10..0x11`, `0x12..0x15` | Song count, start song, speed bits. |
| `0x16..0x35`, `0x36..0x55`, `0x56..0x75` | 32-byte title, author, and released/copyright text. |
| `0x76..0x7B` | v2+ flags and extension bytes; retained in the raw header but not treated as duration. |

The reader intentionally does not infer play time from speed bits or flags.
See [SIDMetadataReader.swift](Sources/MetaManCore/SIDMetadataReader.swift).

### APE and APEv2 / leading ID3v2

Zero or more leading ID3 tags are walked from offset zero. Each ID3 header is
10 bytes; its four-byte synchsafe size is at header `+6`, and a v2.4 footer
adds another 10 bytes. The `MAC ` stream begins immediately after those tags.

For APE versions 3.98+ the descriptor starts at the `MAC ` signature:

| Descriptor position | Meaning |
| --- | --- |
| `+4` | Version, little-endian 16-bit. |
| `+8`, `+12`, `+16` | Descriptor, header, and seek-table byte lengths. |
| `+20`, `+24..+31`, `+32` | WAVE header length, 64-bit audio byte length (low then high words), WAVE tail length. |

The APE header block follows at `streamStart + descriptorLength`: compression
`+0`, flags `+2`, blocks/frame `+4`, final-frame blocks `+8`, frame count
`+12`, bytes/sample `+16`, channels `+18`, sample rate `+20`. The seek table
follows the declared header and contains 32-bit frame offsets relative to the
stream start; declared sizes are checked against the audio payload. For older
versions, the 32-byte legacy header starts at the stream signature and carries
the equivalent fields at its legacy offsets, followed by optional peak/seek
count fields and the seek entries.

An APEv2 footer is the final 32 bytes (`APETAGEX`); version, total tag size,
item count, and flags are at footer `+8`, `+12`, `+16`, and `+20`. Items begin
at `fileEnd - tagSize`; each has a 32-bit value length, 32-bit flags, NUL-ended
key, then value. Text items are decoded, while exact APEv2/ID3 source blocks
remain available. Duration is derived from frame/sample counts, not decoded
audio. See [APEMetadataReader.swift](Sources/MetaManCore/APEMetadataReader.swift).

### CRI / Monster ADX

CRI ADX uses big-endian header fields: marker `0x8000` at `0x00`, offset field
at `0x02` (audio begins at `field + 4`; `(c)CRI` must end immediately before
that position), encoding/frame/depth/channels at `0x04..0x07`, sample rate at
`0x08`, sample count at `0x0C`, high-pass frequency at `0x10`, and version at
`0x12`. Type 03 loop facts are at `0x14` onward. Type 04 places its loop block
after the channel history area beginning at `0x18`, with an optional `AINF`
block before the audio boundary. Type 05 has no loop block in this reader.

The separate Monster Games layout is little-endian: channel count at `0x00`,
loop flag at `0x6E`, sample rate/count at `0x70`/`0x74`, and loop start/end at
`0x78`/`0x7C`. Per-channel data offsets start at `0x34`, one 32-bit value per
`0x34`-byte channel record. Timing is arithmetic from samples/rate and the
established two-loop/ten-second-fade window. See
[ADXMetadataReader.swift](Sources/MetaManCore/ADXMetadataReader.swift).

### Atomic Planet AUS

The whole fixed header is `0x20` bytes. It starts with `AUS `; little-endian
codec is at `0x06`, sample count `0x08`, channels `0x0C`, legacy loop flag
`0x0E`, sample rate `0x10`, loop start/end samples `0x14`/`0x18`, and loop
marker `0x1C`. Loop source values remain available even when invalid bounds
are excluded from timing. See
[AtomicPlanetAUSMetadataReader.swift](Sources/MetaManCore/AtomicPlanetAUSMetadataReader.swift).

### RIFF/WAVE ATRAC3 and ATRAC3+

The file begins `RIFF`, a little-endian container length at byte 4, and `WAVE`
at byte 8. Chunks start at byte 12; each has a four-byte ID, little-endian
32-bit payload size, payload, and one pad byte for odd sizes. The reader walks
chunk boundaries rather than assuming ordering.

| Chunk | Payload fields used |
| --- | --- |
| `fmt ` | WAVE codec/channels/rate/average-byte-rate/block-align/bits at `+0/+2/+4/+8/+12/+14`. Extensible valid bits/mask/GUID at `+18/+20/+24`. |
| `fact` | Sample count at `+0`; ATRAC3 may also carry encoder skip at `+4`. |
| `smpl` | Loop count `+0x1C`, loop type `+0x28`, start `+0x2C`, inclusive end `+0x30`. |
| `wsmp` | Header length `+0`, loop count `+0x10`, loop record length/type `+0x14/+0x18`, start `+0x1C`, length `+0x20`. |
| `LIST` / `INFO` | `INFO` subtype at payload `+0`; then nested four-byte IDs, size words, and NUL-terminated values. |
| `data` | Audio extent is validated and measured, but audio bytes are not copied into metadata blocks. |

The reader preserves non-audio chunks up to its documented retention limit
and applies the codec-specific loop-end/encoder-skip rules used for timing.
See [RIFFATRAC3MetadataReader.swift](Sources/MetaManCore/RIFFATRAC3MetadataReader.swift).

### Sony MSF

The header is `0x40` bytes. Signature occupies bytes `0..2`; big-endian codec,
channels, data size, sample rate, and flags are at `0x04`, `0x08`, `0x0C`,
`0x10`, and `0x14`. If looping is enabled, `0x18` and `0x1C` hold byte-based
loop start and duration. In the non-loop/name layout, the same `0x18..0x3F`
region is interpreted as a bounded C-style stream name (at most `0x27` bytes;
an all-ones sentinel at `0x28` suppresses it). Encoded stream data starts at
`0x40`.

Sample counts come from PCM sample width, PS-ADPCM `0x10`-byte blocks, codec-
specific ATRAC3 frames plus encoder delay, or MPEG frame headers. VBR MPEG is
walked frame by frame so loop byte markers can be mapped to sample boundaries.
See [SonyMSFMetadataReader.swift](Sources/MetaManCore/SonyMSFMetadataReader.swift).

### Konami / SNK SVAG

The reader accepts two distinct 32-byte headers and does not treat an
extension alone as proof of format.

| Layout | Position | Meaning |
| --- | --- | --- |
| Konami `Svag` | `0x04`, `0x08`, `0x0C`, `0x10`, `0x14`, `0x18` | Little-endian data bytes, sample rate, 16-bit channels, interleave block bytes, loop flag, raw loop-start bytes. |
| Konami `Svag` | `0x400` | Optional padding marker (`Svag` or `Desi`); container audio area begins at `0x800`. |
| SNK `VAGm` | `0x08`, `0x0C`, `0x10` | Little-endian sample rate, 32-bit channels, block count. |
| SNK `VAGm` | `0x18`, `0x1C` | Loop start/end blocks. |

PS-ADPCM blocks contribute 28 samples each. Konami data bytes are converted
through channel count and 16-byte ADPCM blocks; SNK loop/block values are
already block indices. Invalid loop bounds remain technical facts but are
omitted from projected timing. See
[SVAGMetadataReader.swift](Sources/MetaManCore/SVAGMetadataReader.swift).

### Konami XMD v1/v2

The extension contains two header layouts. XMD v1 has no fixed magic; the
scanner claims it only when its channel/rate/data bounds are plausible. XMD v2
starts with the ASCII bytes `xmd`. File-URL reads inspect only the fixed header
and filesystem size; audio payload bytes are not loaded or decoded.

| Version | Offset | Width / encoding | Meaning |
| --- | --- | --- | --- |
| v1 (Silent Hill 4) | `0x00` | u8 | Channel count. |
| v1 | `0x01` | u16 LE | Sample rate in Hz. |
| v1 | `0x03` | u32 LE | Encoded data byte count. |
| v1 | `0x07` | u8 | Nonzero enables looping. |
| v1 | `0x08` | u32 LE | Loop-start byte offset in encoded data. |
| v1 | `0x0C` | — | Encoded data begins. The fixed header is 12 bytes. |
| v2 (Castlevania: Curse of Darkness) | `0x00..0x02` | 3 bytes | ASCII `xmd` signature. |
| v2 | `0x03` | u8 | Channel count. |
| v2 | `0x04` | u16 LE | Sample rate in Hz. |
| v2 | `0x06` | u32 LE | Encoded data byte count. |
| v2 | `0x0A` | u8 | Nonzero enables looping. |
| v2 | `0x0B` | u32 LE | Loop-start byte offset in encoded data. |
| v2 | `0x0F..0x10` | 2 bytes | Unknown header values, retained verbatim. |
| v2 | `0x11` | — | Encoded data begins. The fixed header is 17 bytes. |

V1 uses 13-byte frames with 16 samples per frame; v2 uses 21-byte frames with
32 samples per frame. To match vgmstream's integer arithmetic, the reader
divides encoded bytes by frame size, then by channel count, before multiplying
by samples per frame. The loop-start byte offset is converted with the same
operation order. With looping disabled, the scanner play length is the stream
sample count. With looping enabled, the former CLI metadata projection uses
loop-start samples plus two loop bodies and a ten-second fade. MetaMan retains
the source sample/loop facts and this scanner-compatible play-length projection
without audio decoding. See
[KonamiXMDMetadataReader.swift](Sources/MetaManCore/KonamiXMDMetadataReader.swift).

### Sony SSHD / ADS

The same `SShd`/`SSbd` byte layout is also used under the `.ss2` suffix
(described by vgmstream as a demuxed-video stream alias). `.ss2` adds no
separate offset map; the content signature and full SSHD header validation
decide whether MetaMan claims it.

The native stream begins with a 40-byte `SShd` header. The reader also
accepts the two vgmstream container wrappers when the inner stream is valid:
`ADSC` version 1 places the stream at `0x08`, and Cavia's ASCII
`cavi a stream` wrapper places it at `0x7D8`. Offsets below are relative to
the inner `SShd` stream, not the outer file.

| Offset | Width / encoding | Meaning |
| --- | --- | --- |
| `0x00..0x03` | 4 bytes | ASCII `SShd` signature. |
| `0x04` | u32 LE | Header-size variant: `0x18`, `0x20`, or inner file size minus `8`. |
| `0x08` | u32 LE | Codec: `0x01`/`0x80000001` PCM16LE, `0x02`/`0x10` PS-ADPCM. The `0x01` + 12,000 Hz + `0x200` interleave combination is the video DVI-IMA variant. |
| `0x0C` | s32 LE | Source sample rate. DVI-IMA is normalized to 48,000 Hz. |
| `0x10` | s32 LE | Channel count. |
| `0x14` | u32 LE | Source interleave block size. DVI-IMA uses an effective `0x40` block size. |
| `0x18` | u32 LE | Raw loop-start value; maker-specific address or sample units. `0xFFFFFFFF` means unset. |
| `0x1C` | u32 LE | Raw loop-end value; `0xFFFFFFFF` is the open-ended marker. |
| `0x20..0x23` | 4 bytes | ASCII `SSbd` body marker. |
| `0x24` | u32 LE | Declared encoded body size. It is clamped to the physical remainder and corrected for the known doubled-size layout. |
| `0x28...` | bytes | Encoded stream body. It normally starts at `0x28`, at `0x800` for sector-padded files, or at `0xFF8` for the ADSC alignment case. |

PS-ADPCM uses 16-byte frames per channel and contributes 28 samples per
frame. PCM16LE uses two bytes per sample per channel. DVI IMA uses two samples
per encoded byte per channel. The reader scans only the trailing PS-ADPCM
interleave for vgmstream's `0x07`, zero, `0x77777777`, Cavia-silent, and
Capcom-silent padding frames; those bytes are excluded from the sample count.

SSHD loop fields are not one universal unit. The reader mirrors the decoder's
ordered branches: Capcom codec `0x02` uses `loopStart * 0x10`, `PAD!` uses PCM
bytes, sector-aligned Cavia values subtract `0x800`, unaligned values use
`* 0x10`, paired values may use `* 0x200`, `* 0x70`, or `* 0x20`, and large
paired values are already samples. A recognized non-looping PS-ADPCM sound
effect is identified from the `0x00077777` marker after the candidate end.
Projected looping uses the scanner's loop start plus two loop bodies and a
ten-second fade; invalid or out-of-range loops remain raw technical facts but
are removed from projected timing. The reader retains the first `0x28` bytes
of the inner header as `sshdHeader` and never copies or decodes audio payload.

See [SonySSHDMetadataReader.swift](Sources/MetaManCore/SonySSHDMetadataReader.swift).

### Headerless PlayStation MIB

The live `.mib` files are raw PlayStation ADPCM streams with no container
header, text tag block, or stored sample-rate field. The extension supplies
44,100 Hz. MetaMan uses the same bounded probe and inference rules as
vgmstream's headerless PS-ADPCM reader, but does not instantiate its decoder.

| Offset / scope | Width / encoding | Meaning |
| --- | --- | --- |
| `0x00` of each `0x10`-byte frame | u8 | PS-ADPCM predictor/shift byte; its high nibble must be `0..5` during the `0x2000`-byte format probe. |
| `0x01` of each frame | u8 | PS-ADPCM flags; values above `0x07` fail the probe. `0x06` marks a loop start, `0x03` a loop end unless byte `0x03` is `0x77`, and `0x04` marks a loop-to-end start. |
| `0x02..0x0F` of each frame | 14 bytes | ADPCM payload and channel-boundary comparison data. Channel inference ignores `0x00..0x01` when comparing a non-empty frame with the first frame. |
| `0x00`, then every `0x10` bytes | — | Frame stride. The full-file walk uses repeated empty-frame signatures to infer interleave and channel count; interleave defaults to `0x10`. |
| `0x00..0x1FFF` | up to `0x2000` bytes | Bounded PS-ADPCM validity probe; no fixed file header is assumed. |
| Extension | — | `.mib` selects 44,100 Hz. The separate `.mib` + `.mih` bank handler is not this live layout and is not claimed by this reader. |
| Full file | — | Decoded samples are `floor(fileBytes / 0x10 / channels) * 28`. Loop byte positions are converted with the decoder-compatible mono/interleaved formulas, including the legacy mono start multiplier. |

The reader retains the first frame as `mibProbeHeader`, exposes raw loop and
inference facts, and falls back to the source filename for the title because
the raw stream contains no text metadata. ScanSong content-routes validated
headerless `.mib` files to this reader; a probe failure remains on the generic
vgmstream route. The live corpus contains 327 files in eight archives, all
with no `.mih` companion entries. See
[MIBMetadataReader.swift](Sources/MetaManCore/MIBMetadataReader.swift).

### Mixed ADP layouts

The `.adp` suffix is shared by unrelated decoder formats. MetaMan claims only
the two layouts that can be completely identified from the source and its
declared companion. ScanSong probes the content before selecting
`adp-direct`; an unrecognized `.adp` remains on vgmstream rather than being
partially extracted.

#### Headerless Nintendo GameCube DTK

This is the GameCube DVD hardware DTK stream with no file header. The probe is
the same bounded signature used by the reference decoder: ten complete frames,
or `0x140` bytes, must be available. Every frame has a 0x20-byte stride; the
first header byte has an index nibble no greater than 4 and a shift nibble no
greater than `0x0C`, bytes `+0x00/+0x01` repeat at `+0x02/+0x03`, and no more
than three of the ten headers may be `0x0000`.

| Offset / scope | Width / encoding | Meaning |
| --- | --- | --- |
| `0x00` of each `0x20`-byte frame | u8 | Predictor/index and shift header; high nibble `0..4`, low nibble `0..0x0C`. |
| `0x01` of each frame | u8 | Second header byte; it must repeat at `+0x03`. |
| `0x02..0x03` of each frame | 2 bytes | Error-correction repeat of the first two header bytes. |
| `0x04..0x1F` of each frame | 28 bytes | Nintendo DTK encoded payload; the reader does not decode it. |
| `0x00..0x13F` | 0x140 bytes | Required ten-frame bounded probe. |
| Full file | — | `floor(fileBytes / 0x20) * 28` stereo samples at 48,000 Hz; there are no embedded tags or loops. |

The live DTK corpus contains 175 `.adp` members. The first frame is retained
as `dtkProbeHeader`; the filename stem is the only available visible title.

#### Raw IMA with `.adp.txth`

The Contra archive stores raw IMA bytes and a hidden `.ADP.txth` sidecar. The
sidecar is not a source track; it is the complete layout declaration for the
adjacent `.ADP` members. MetaMan accepts the exact supported directive set
below, retains the original sidecar bytes, and rejects additional directives
until their semantics can also be represented completely.

| Sidecar directive | Value / meaning |
| --- | --- |
| `codec` | `IMA`; 4-bit IMA ADPCM. |
| `sample_rate` | Positive sample rate in Hz; the live sidecar declares `48000`. |
| `channels` | One or two interleaved channels; the live sidecar declares mono. |
| `num_samples` | Must be `data_size`; for IMA this is converted to `fileBytes * 2 / channels` samples. |
| Sidecar extent | UTF-8 text, bounded to 64 KiB, beside the source as `.adp.txth` case-insensitively. |

The live sidecar contains no title, artist, game, loop, or fade metadata, so
the source filename supplies the title and timing is finite. The nine live
TXTH-described files are not confused with headerless DTK even though both
use `.adp`.

The live read-only comparison covered all 184 `.adp` rows/files: direct
MetaMan, the ScanSong adapter, the saved catalog, and fresh vgmstream matched
exactly. Release inspection averaged 0.129 ms/file directly versus 96.569
ms/file through the CLI, including per-file process startup. These are local
corpus measurements, not a whole-scan or cross-machine guarantee.

See [ADPMetadataReader.swift](Sources/MetaManCore/ADPMetadataReader.swift)
and the reference dispatch in
[`ngc_adpdtk.c`](../VGMBoy/vendor/vgmstream/src/meta/ngc_adpdtk.c).

### CRI AHX

AHX is recognized only when its compact header, dynamic CRI marker, and first
fixed AHX frame are all present. The reader uses the header and payload extent
for metadata; it does not run the MPEG/AHX playback decoder.

| Offset / scope | Width / encoding | Meaning |
| --- | --- | --- |
| `0x00` | u16 BE | `0x8000` AHX signature. |
| `0x02` | u16 BE | Relative header field; `dataOffset = value + 4`. |
| `0x04` | u8 | AHX type; the direct route accepts `0x10` and `0x11`. |
| `0x05..0x06` | 2 bytes | Reserved zeros required by the direct probe. |
| `0x07` | u8 | Channel count; the live CRI layout is mono (`1`). |
| `0x08` | s32 BE | Sample rate in Hz. |
| `0x0C` | s32 BE | Authored/declared sample count, retained as a source fact. |
| `0x12` | u8 | AHX version marker; direct files use `0x06`. |
| `0x13` | u8 | Encryption type, retained without attempting decryption. |
| `dataOffset - 0x06` | 2 bytes | Dynamic `(c` marker. |
| `dataOffset - 0x04` | 4 bytes | Dynamic `)CRI` marker. |
| `dataOffset` | 4 bytes | Fixed first AHX frame word `FF F5 E0 C0`. |
| `dataOffset .. fileEnd` | variable | Fixed 160,000-bit/s payload used for scanner-compatible duration. |
| `fileEnd - 0x10` | 16 bytes, optional | `80 01 00 0C AHXE(c)CRI 00 00` footer retained when present. |

For the current scanner projection, `payloadBytes = fileBytes - dataOffset`,
`decodedSampleCount = round(payloadBytes * sampleRate * 8 / 160000)`, and
`playLengthMs = floor(decodedSampleCount * 1000 / sampleRate)`. The two sample
counts are intentionally distinct: the header's declared count is preserved,
while the payload-derived count reproduces the existing FFmpeg inspection.
The live 11-file corpus matched saved catalog rows and fresh vgmstream rows
exactly; direct Release inspection averaged 0.160 ms/file versus 35.398 ms/file
for the CLI. See
[AHXMetadataReader.swift](Sources/MetaManCore/AHXMetadataReader.swift).

### Konami Saturn DVI

The `.dvi` suffix is shared by Konami Saturn `DVI.` streams and unrelated
Capcom `IDVI` streams. MetaMan claims only the complete `DVI.` layout below.
All multi-byte values are signed big-endian 32-bit integers.

| Offset / scope | Width / encoding | Meaning |
| --- | --- | --- |
| `0x00..0x03` | 4 bytes | ASCII `DVI.` signature. `IDVI` is deliberately not claimed. |
| `0x04..0x07` | s32 BE | Payload/data offset; live files use `0x800`. |
| `0x08..0x0B` | s32 BE | Total sample count. |
| `0x0C..0x0F` | s32 BE | Loop-start sample; `-1` means no loop. |
| `0x10..dataOffset-1` | raw bytes | Pre-payload header/ADPCM state; retained as `dviHeader`. |
| `dataOffset..fileEnd` | raw bytes | Stereo Intel DVI/IMA payload, 4-byte interleave, 44.1 kHz. |
| Whole file | invariant | `fileBytes - dataOffset == sampleCount`; otherwise the direct route rejects the source as incomplete or ambiguous. |

For a non-looping source, play samples equal the header sample count. For a
looping source, the scanner-compatible finite projection is
`loopStart + 2 * (sampleCount - loopStart) + 44100 * 10`; milliseconds are
integer floor division by 44,100. The direct reader retains the complete
pre-payload header but never decodes the IMA payload. See
[DVIMetadataReader.swift](Sources/MetaManCore/DVIMetadataReader.swift).

### Bink audio containers (`.bika`)

The live `.bika` members are self-contained RAD Game Tools Bink containers
with their extension changed to distinguish demuxed audio members from movie
`.bik` inputs. MetaMan reads the container header, stream table, frame-offset
table, and audio-packet headers; it never runs the Bink transform decoder.
The packet walk is required because Bink audio is variable-sized and the main
header does not store the decoded sample count.

| Offset / scope | Width / encoding | Meaning |
| --- | --- | --- |
| `0x00` | 4 bytes, big-endian | `BIK` or `KB2` signature plus the revision byte. |
| `0x04` | u32 LE | Declared file size minus eight; it must equal the physical file size minus eight. |
| `0x08` | u32 LE | Video frame count; the direct reader bounds it to one million before walking the offset table. |
| `0x0C` | u32 LE | Largest frame size, retained as a source fact when clients need it. |
| `0x10` | u32 LE | Repeated frame count used by Bink files; it is retained in the raw header but does not replace `0x08`. |
| `0x14`, `0x18` | s32 LE each | Video width and height. |
| `0x1C`, `0x20` | u32 LE each | Video frame-rate dividend and divisor. |
| `0x24` | u32 LE | Video flags. Bit `0x000004` inserts six 16-bit values; bit `0x010000` inserts twelve 16-bit values before the audio tables. |
| `0x28` | s32 LE | Number of audio streams, bounded to 1..256. |
| After `0x2C` | optional u32 and variable blocks | BIK revisions `k+` or KB2 revisions `i+` add a color-flags word; the video-flag blocks follow when present. |
| Stream table 1 | u32 LE per stream | Maximum packet sizes. |
| Stream table 2 | u16 LE + u16 LE per stream | Sample rate and audio flags. Flag `0x2000` selects stereo; flag `0x1000` identifies DCT rather than RDFT audio. |
| Stream table 3 | u32 LE per stream | Native stream IDs. |
| Frame-offset table | u32 LE per frame | Absolute frame offsets; the low keyframe bit is masked before seeking. A trailing u32 repeats the declared physical file size. |
| Each frame, per audio stream | u32 LE | Audio packet size excluding this size field. |
| Each non-empty audio packet +`0x04` | u32 LE | Decoded byte count for that packet; summing this value and dividing by `2 * channels` yields decoded samples. |
| Full file | — | `play_length_ms = decodedSampleCount * 1000 / sampleRate`; Bink inputs have no decoder-reported loop markers in this route. |

MetaMan publishes one ordered `MetadataTrack` per audio stream. The legacy
vgmstream Bink parser uses the same frame-offset and packet-sample walk, so the
reader can be completely independent for metadata while Bink playback remains
in VGMBoy. The live one-archive corpus contains 68 `.bika` files: all 68 direct
rows match the saved catalog, all 68 decoder rows match it, and all 68 direct
rows match the fresh vgmstream reference. Release inspection averaged
3.118 ms/file directly versus 91.143 ms/file through the CLI reference.
`.bik`/`.bk2` movie extensions remain on the vgmstream playback/inspection
boundary and are not silently claimed by the `.bika` metadata reader.

See [BinkAudioMetadataReader.swift](Sources/MetaManCore/BinkAudioMetadataReader.swift).

## What this says about decoder independence

For some formats the answer really is a header/tag layout plus bounded parsing.
That is enough for AY, SAP, SID, PSF tags, and several fixed-header audio
containers. Others require more work: S98 timing walks commands, APE validates
its seek table and frame extents, RIFF follows nested padded chunks, and VBR
MSF counts encoded frames. None of those steps requires rendering audio, but
they are more than reading a handful of offsets.

There are verified cases where the direct metadata path exposes more than the
decoder's info projection:

- **SPC xID6:** MetaMan retains soundtrack title/disc/track and the extended
  intro/loop/end/fade timing items. Current upstream libgme reads only selected
  xID6 fields; its intro-length handler is explicitly commented out, and it
  does not map the soundtrack title/disc/track IDs into track info. The local
  read-only comparison recorded 662 source-explained differences across
  77,326 SPC rows and zero unexplained MetaMan/libgme differences. This is a
  specific, tested completeness advantage—not a claim that every field is
  universally superior. See the [libgme SPC info reader](https://raw.githubusercontent.com/libgme/game-music-emu/master/gme/Spc_Emu.cpp)
  and [SPCMetadataReader.swift](Sources/MetaManCore/SPCMetadataReader.swift).
- **S98:** MetaMan preserves arbitrary/repeated v3 keys, including full `DATE`,
  and computes loop duration from the actual loop event. The prior libvgm
  scanner projection reported loop duration as intro duration; preserving that
  defect would have made the direct reader less correct.
- **SID:** the direct reader fixes the former ScanSong parser's overlapping
  author/released text offsets. This corrects our previous parser, not a claim
  about libsidplayfp.

Other migrations primarily move ownership, expose native source facts, or
match a decoder/catalog projection without removing that playback dependency.
Use the per-format parity notes in [README.md](README.md) for the evidence
level and limits of each claim.
