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
