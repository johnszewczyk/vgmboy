# MetaMan

MetaMan is a decoder-independent metadata-reading library for game-audio and
other media files. Its reusable product is `MetaManCore`; the `metaman` command
is a thin JSON interface for scripting and support work. Applications should
import the library rather than shelling out to the CLI.

MetaMan currently has complete AY, SAP, NSF, GBS, NSFE, HES, SNDH, KSS, S98,
VGM/VGZ, generic PSF-style tags, complete GSF/miniGSF and QSF/miniQSF,
SPC ID666/xID6, SID PSID/RSID, APE, CRI/Monster ADX,
Atomic Planet AUS, RIFF ATRAC3/ATRAC3+, Sony MSF, Sony SSHD/ADS,
Konami/SNK SVAG, Konami XMD v1/v2, Sony CD-XA, headerless PlayStation MIB,
Bink audio containers,
headerless Nintendo GameCube DTK and exact TXTH-described IMA ADP streams,
CRI AHX,
standard Nintendo DS STRM, Final Fantasy Tactics A2 RIFF/IMA, Nintendo DSP,
Retro Studios RS03, and Nintendo THP audio readers. SAP enumerates declared
subtunes from ordered header directives and retains native `TIME` hints. The
S98 reader handles header/device information, its complete v3 tag block (including arbitrary and repeated
keys), legacy pre-v3 titles, and register-command timing. The VGM reader
handles the common header, timing fields, gzip-compressed VGZ input, and the
complete standard GD3 field sequence. These readers do not instantiate a
playback core. Unknown fields, both GD3 language variants, and original tag
bytes remain available to clients.

The [format layout map](FORMAT-LAYOUTS.md) records the byte offsets, pointer
bases, chunk boundaries, and variable-length walks each reader currently uses.
It is an implementation map, not a claim that every format is a flat set of
fixed offsets or that the decoder is needed to locate every field.

| Format | Read path | Metadata / timing | Write support |
| --- | --- | --- | --- |
| AY | Direct ZXAYEMUL header and signed relative-pointer parser; no playback player | Ordered per-subtune documents, raw header/table/text/info blocks, source facts, and native 50 Hz lengths with the prior 150-second fallback | Not implemented |
| SAP | Direct CR/LF information-header and `FF FF` data-marker parser; no playback core | Ordered `SONGS` subtunes, directives/tags, source header bytes, and per-track finite or loop-start `TIME` hints | Not implemented |
| NSF / GBS | Direct fixed-header readers; no emulator | Ordered header-declared tracks, fixed identity fields, raw headers, and playback/timer setup facts; scanner-compatible unknown/default timing | Not implemented |
| NSFE | Direct bounded chunk reader; embedded NSF `DATA` is not decoded | Ordered visible tracks with source indices, repeated `PLST` entries, labels/authors, authored time/fade, hardware facts, and retained non-audio chunks | Not implemented |
| HES | Direct `HESM` header and bounded same-basename M3U parser; no PC Engine emulation | Ordered playlist rows with address slots, titles, identity, intro/loop/play/fade timing, raw header and playlist bytes; 256 compatibility slots without M3U | Not implemented |
| SNDH | Direct executable-vector-bounded tag/subtune/timing parser with bounded ICE! expansion; no Atari ST playback core | Ordered subtunes, Atari ST text, retained tag bytes, native TIME/FRMS timing, and source facts | Not implemented |
| KSS / KSSX | Direct fixed header plus bounded KSSX extension reader; no Z80 or playback core | 256 compatibility entries, hardware flags, raw header blocks, and declared KSSX data/track facts; established info-only timing defaults | Not implemented |
| S98 v0-v3 | Direct header, tag-block, device-table, and command-stream parser | Ordered raw tags, normalized common fields, technical header facts, and stream timing | Not implemented |
| VGM / VGZ | Direct 64-byte header and GD3 parser; bounded gzip inflate for compressed input | All 11 ordered GD3 fields (plus future extras), original-language values, release date, converter, notes, header facts, and 44.1 kHz sample timing | Not implemented |
| PSF / PSF2 / SSF / USF / 2SF | Direct PSF-style header and `[TAG]` footer parser; no playback core | Ordered tags including duplicates and unknown keys, raw footer bytes, normalized identity, authored length/fade, and console identity by extension | Not implemented |
| GSF / miniGSF | Complete PSF v0x22 container, GBA segment, and PSFLib-chain validation; no mGBA | Ordered source tags, raw PSF headers/tag blocks, dependency and segment facts, GBA ROM-header validation, and inherited timing | Not implemented |
| QSF / miniQSF | Complete PSF v0x41 container, QSound-block, and declared QSFLib validation; no playback core | Ordered root tags, raw PSF headers/tag blocks, source/block facts, and authored length/fade | Not implemented |
| SPC | Direct text/binary ID666 header and xID6 chunk parser; no playback emulator | Ordered metadata, dump date, dumper/emulator facts, soundtrack fields, native timing, and separately retained ID666/xID6 source blocks | Not implemented |
| SID (PSID / RSID) | Direct fixed-header parser; no playback core | Title, author, release text, technical header facts, and retained raw header; no duration inferred from flags | Not implemented |
| APE | Direct descriptor, seek-table, APEv2, and leading ID3v2 parser; no audio decoder | Ordered text tags, normalized common fields, exact ID3v2/APEv2 blocks, technical header facts, and sample-count duration | Not implemented |
| CRI / Monster ADX | Direct CRI type-03/04/05 and Monster Games header parser; no audio decoder | Filename-derived title, source label, exact header bytes, sample/channel/loop facts, and sample-derived loop/play timing | Not implemented |
| Atomic Planet AUS | Direct 32-byte header and loop-timing parser; no audio decoder | Filename-derived title, source label, exact header bytes, codec/sample/channel/loop facts, and sample-derived loop/play timing | Not implemented |
| RIFF/WAVE ATRAC3/ATRAC3+ | Direct RIFF chunk reader for codec `0x0270` and the ATRAC3+ extensible GUID; no audio decoder | Ordered `LIST/INFO` tags, exact named non-audio chunks, codec/fact/loop facts, and vgmstream-compatible play timing | Not implemented |
| Sony MSF | Direct 64-byte container-header and MPEG frame-boundary parser; no audio decoder | Header stream name, exact header bytes, codec/channel/rate/loop facts, and PCM/PSX ADPCM/ATRAC3/MPEG sample timing; non-Sony aliases are not claimed | Not implemented |
| Konami / SNK SVAG | Direct `Svag` and `VAGm` header parsers; no audio decoder | Exact structural header bytes, native codec/channel/rate/interleave/block/loop facts, and validated sample-derived loop/play timing; unrelated `.svag` aliases are not claimed | Not implemented |
| Konami XMD v1/v2 | Direct 12-byte Silent Hill 4 or 17-byte Castlevania header reader; audio payload is not read by the file-URL API | Raw header, channels/rate/data extent, ADPCM frame/sample counts, loop facts, and the scanner's two-pass/10-second-fade duration projection | Not implemented |
| Sony SSHD / ADS | Direct `SShd` header and bounded PS-ADPCM/PCM/DVI-IMA frame-timing reader; no audio decoder | Codec/channel/rate/interleave facts, wrapper/header bytes, encoded-body bounds, decoder-compatible loop-address handling, and scanner timing; nonmatching `.ads` aliases are not claimed | Not implemented |
| Headerless PlayStation MIB | Direct PS-ADPCM frame probe and channel/interleave/loop inference; no audio decoder | Extension-defined 44.1 kHz, raw probe block, inferred layout, decoder-compatible sample/timing facts, and filename fallback; `.mib` files that fail the probe remain on vgmstream fallback | Not implemented |
| Bink audio (`.bika`) | Direct Bink header, offset-table, and audio-packet walk; no Bink decoder | Filename fallback, retained container header, stream/channel/rate facts, decoded sample count, and packet-derived finite duration; `.bik` movie inputs remain outside this reader | Not implemented |
| Nintendo GameCube DTK (`.adp`) | Direct first-ten-frame headerless DTK probe and frame/sample arithmetic; no decoder | Filename fallback, raw probe frame, stereo/48 kHz facts, and finite duration; unknown `.adp` aliases remain on vgmstream | Not implemented |
| TXTH-described IMA (`.adp` + `.adp.txth`) | Direct bounded TXTH directive parser and IMA bytes-to-samples arithmetic; no decoder | Retained sidecar, ordered directives, codec/channel/rate facts, and finite duration; unsupported TXTH directives remain on vgmstream | Not implemented |
| CRI AHX | Direct bounded header and fixed 160 kbps payload-duration reader; no MPEG/AHX decoder | Filename-derived title, exact AHX header/footer blocks, rate/channel/type/encryption facts, declared and scanner-projected sample counts, and finite duration | Not implemented |
| Sony CD-XA | Direct raw-sector and RIFF/CDXA parser; no ADPCM decoder | Ordered file/channel subsongs, sector/sample facts, and sector-derived duration; unrelated `.xa` aliases are not claimed | Not implemented |
| Nintendo DS STRM | Direct standard `STRM`/`HEAD`/`DATA` container and sample-header reader; no playback core | Codec, channels, rate, sample/loop counts, interleave facts, exact header blocks, and scanner-compatible sample timing | Not implemented |
| Nintendo DS FFTA2 STRM | Direct Square Enix RIFF/IMA fixed-header reader; no playback core | Header-derived sample count, channel/rate/loop facts, exact header block, and scanner-compatible sample timing; supports `.bin` and `.strm` | Not implemented |
| Nintendo DSP (standard) | Direct big-endian 0x60-byte DSPADPCM header reader; no audio decoder | Codec coefficients, sample/nibble counts, loop points, exact header, and scanner-compatible timing | Not implemented |
| Retro Studios RS03 | Direct `RS03` fixed-header reader; no audio decoder | Channel/interleave facts, byte-addressed loops, sample timing, and exact header | Not implemented |
| Nintendo THP audio | Direct versioned THP component-table and DSP audio-header walk; no video or audio decoder | Channels, sample rate/count, component layout, raw header blocks, and finite timing | Not implemented |

This is a library first, not a CLI-only tool. The `metaman` executable is an
optional JSON frontend; CocoaSpice, ScanSong, and future clients can consume
`MetaManCore` directly. File reading and tag interpretation stay together in
the core, while clients own their transport, catalog, and UI concerns.

`MetaManCore.readResult` is the ordered per-file/per-track contract. Each
`MetadataTrack` carries a complete `MetadataDocument` and an optional
format-native `sourceTrackIndex`; result-array order is authoritative, and
repeated source indices remain separate entries. AY, SAP, NSF, GBS, NSFE,
HES, SNDH, KSS, and Sony XA use this contract; GSF publishes one validated
entry. The file-URL API loads only format-declared companions: a same-basename
M3U for HES and explicitly named, source-directory-confined PSFLib files for
GSF. Data callers pass bounded named companion bytes through
`MetadataReadContext`; MetaMan does not follow playlist text or arbitrary paths. Use
`metaman read-tracks <file>` for the ordered JSON result. The legacy
`metaman read <file>` command remains a single-document API and rejects these
track-aware formats rather than silently discarding subtunes. SNDH tags `##`,
`!#`, `!#SN`, `TIME`, and `FRMS` retain native order; the reader applies the
Atari ST character map and defaults missing or zero frame-timer rates to 50 Hz.

KSS retains the fixed 16-byte `KSCC`/`KSSX` header and, for a valid KSSX
extension of exactly 16 bytes, its additional 16-byte header. It records the
load/init/play addresses, banking/device flags, declared payload size, track
range, and mixer-volume bytes without executing the Z80 program. To preserve
the current ScanSong/catalog and installed libgme 0.6.5 info-only behavior,
the ordered result still publishes the 256-slot compatibility range even when
KSSX declares a smaller track range; that native range is exposed separately
as `declaredFirstTrack`, `declaredLastTrack`, and `declaredTrackCount`. The
normalized system field preserves ScanSong's established device-flag labels;
the scanner now only adapts the shared document. KSS M3U playlists remain
unconsumed. The field offsets are listed in
[FORMAT-LAYOUTS.md](FORMAT-LAYOUTS.md).

The Sony XA reader recognizes raw 2352-byte sectors and RIFF/CDXA-wrapped
sectors, then walks their subheaders to enumerate ordered file/channel
subsongs. It applies the vgmstream-compatible audio-sector predicate,
per-channel end-of-track reset, coding-mode/sample-rate rules, and raw-sector
frame sanity probe; it does not decode ADPCM. Each document keeps the visible
title, source label, sector count, XA file/channel configuration, coding info,
sample rate, sample count per sector, and derived duration. Single-track names
fall back to the source filename; multiple tracks use the four-digit
file/channel code. ScanSong routes matching XA signatures and adapts the
ordered result, leaving unrelated `.xa` aliases on vgmstream. The byte layout
and bounds are in [FORMAT-LAYOUTS.md](FORMAT-LAYOUTS.md).

The standard Nintendo DS STRM reader recognizes `STRM` with valid `HEAD` and
`DATA` headers. It reads codec, channels, sample rate/count, loop points, and
interleave facts without decoding or retaining sample payload. The FFTA2
variant is distinct: it begins `RIFF`/`IMA `, stores its complete file size at
`0x04`, and exposes the loop start/end and sample rate in its fixed header.
Both readers preserve only their fixed metadata headers. To match the former
scanner projection, looped play time is loop start plus two loop bodies plus a
ten-second fade; loop length is zero when looping is disabled. ScanSong routes
both validated layouts directly and keeps vgmstream fallback for unrelated
`.strm` aliases. See [FORMAT-LAYOUTS.md](FORMAT-LAYOUTS.md#nintendo-ds-strm)
and [the FFTA2 layout](FORMAT-LAYOUTS.md#nintendo-ds-ffta2-riffima).

The HES reader validates the fixed `HESM` header, reads its three variable-width
text fields, and retains header facts and exact source bytes. Its M3U parser is
bounded to 4 MiB and 65,536 rows; it preserves ordered comments/tags and row
order, maps hexadecimal address slots and decimal ordinals, and reads authored
titles and intro/loop/play/fade times. Without M3U it returns libgme-compatible
256 address slots, unknown intro/loop/fade facts, and the 150-second fallback.
For catalog compatibility, ScanSong alone maps those fallback timing fields to
zero as the former scanner did. See the HES entry in
[FORMAT-LAYOUTS.md](FORMAT-LAYOUTS.md).

The AY reader validates the `ZXAYEMUL` header and complete track-pointer table,
follows bounded signed big-endian relative pointers, and reads each title,
file-level author/comment, and six-byte per-track info record. It retains the
header, pointer table, and referenced text/info bytes in named raw metadata
blocks, with version, player id, first-track byte, native source index, and
50 Hz frame count in `technicalFacts`. Positive frame counts map to
milliseconds (`frames * 20`); absent or zero lengths retain the previous
150-second info-only fallback. Intro, loop, and fade remain unknown (`-1`),
matching the previous ScanSong projection. No embedded Z80 player is run.

The SAP reader starts at the five-byte `SAP\r\n` signature and walks CR/LF
directives until the first `FF FF` marker; it caps and retains the exact
information header. `SONGS` controls ordered subtune count (default one), and
repeated `TIME` directives map to corresponding source indices. Plain `TIME`
is a finite duration; `TIME … LOOP` is the intro/loop-start position and keeps
the prior 150-second play fallback. `NAME`, `AUTHOR`, and `DATE` populate
normalized fields, while all directives—including unknown and repeated keys—
remain in ordered tags and raw bytes. No Atari CPU or POKEY playback core is
started. The `metaman read` singular API refuses SAP to avoid flattening its
track result.

The S98 parser stops timing at the format's `FD` end command. A header loop
pointer is accepted only when it identifies an event before that end; stale
pointers after `FD` are diagnosed and omitted instead of becoming a fabricated
full-song loop. A truncated final register write does not erase timing from
complete preceding events: the partial write is ignored and reported in
`diagnostics`. Other malformed timing commands still fail explicitly. These
cases were found by comparing the direct reader with current catalog files and
the vendored libvgm reference; libvgm's ScanSong bridge reports loop duration
as intro duration, so exact decoder parity would preserve a known timing bug.

The S98 v3 tag set permits arbitrary user-defined keys, so `DATE` is retained
even though it is not one of the format's listed basic keys. MetaMan does not
invent a full date from `YEAR` or filesystem timestamps. The local catalog
comparison covers all 5,081 current S98 rows: 1,178 match libvgm exactly, and
3,903 differences are classified improvements (including 14 rows with a full
`DATE`). In optimized Release measurement, direct-read median/p95 are
0.136/0.511 ms versus libvgm's 0.142/0.508 ms. This is a read-only local-corpus
result, not a cross-machine guarantee.

The S98 v3 format permits user-defined tag names and specifies UTF-8 when a BOM
follows `[S98]`, otherwise the legacy Japanese multibyte encoding. Its basic
tag set includes `title`, `artist`, `game`, `year`, `genre`, `comment`,
`copyright`, `s98by`, and `system`; MetaMan retains additional keys instead of
dropping them. See the [S98 v3 specification](https://github.com/rururutan/s98spec3/blob/master/s98spec3-en.md).

GD3 stores 11 ordered UTF-16LE values: English and original-language title,
game, system, and artist; release date; converter; and notes. MetaMan retains
both language values, prefers English for normalized common fields when
present, and falls back to the original-language value. `fields.date`,
`fields.encodedBy`, and `fields.comment` expose release date, converter, and
notes independently. Header timing is taken from total and loop sample counts
at 44.1 kHz; no audio is rendered. VGZ data is inflated in-process with a
256 MiB output limit. The raw GD3 tag, including its on-file header, remains in
`rawTagBlock`. See the [VGM specification](https://vgmrips.net/wiki/VGM_Specification)
and [GD3 specification](https://vgmrips.net/wiki/GD3_Specification).

The PSF-family reader covers `.psf`/`.minipsf`, `.psf2`/`.minipsf2`,
`.ssf`/`.minissf`, `.usf`/`.miniusf`, and `.2sf`/`.mini2sf`. It reads their
shared `[TAG]` footer without validating or emulating the compressed program
body; authored `length` and `fade` tags provide timing. Ordered duplicate and
unknown tags, the original footer, UTF-8 diagnostics, and the header fields
used to locate that footer remain available. GSF and QSF are not handled by
this generic reader because they require complete format-specific container
and dependency validation. Each has a complete MetaMan reader.

The GSF reader validates PSF version `0x22`, the declared reserved/compressed
ranges, CRC-32, and the zlib stream for the root and each declared PSFLib. It
retains ordered source tags (including repeated and unknown keys), exact PSF
header/tag blocks, and per-source container/segment facts. It follows `_lib`,
then contiguous `_lib2`, `_lib3`, and later references in the established
load order; nested `_lib` is visited before its owning executable segment. The
12-byte GSF executable header supplies a masked load offset at `0x04` and
declared image size at `0x08`, followed by segment bytes at `0x0C`. Segments
are stitched only far enough to validate the GBA image header against the old
mGBA recognition/fallback and BIOS-rejection checks; no GBA code is executed.
Root authored `length`/`fade` values and inherited library tags retain
ScanSong's existing timing projection. File reads reject path traversal and
symlink escapes, limit each container to 128 MiB, aggregate dependency bytes to
512 MiB, the chain to 256 files / depth 10, inflated segments to 64 MiB, and
the assembled ROM image to 64 MiB. See the offset-by-offset
[GSF layout](FORMAT-LAYOUTS.md#gsf--minigsf--psf-v0x22) for details.

### QSF / miniQSF complete reader

MetaMan validates the root PSF version `0x41`, reserved/compressed ranges,
CRC-32, bounded zlib output, and every QSound data block. It preserves the
root's ordered tags and exact tag bytes, plus each source's PSF header, any
reserved bytes, and block-kind/address/length facts. Root tags provide the
normalized fields and authored timing; duplicate tags remain in order while
the compatibility projection uses the last value, as the former ScanSong
reader did. A missing title falls back to the source filename. The timing
parser retains the QSound playback bridge's numeric-prefix behavior and
44.1-kHz frame quantization. Intro and loop remain zero, matching the previous
scanner projection.

The root's `_lib` through `_lib9` names are checked in loader order. Every
referenced QSFLib is validated as a PSF container and its decompressed QSound
blocks are checked, but library tags do not override root metadata and library
`_lib` values are not followed recursively. File-URL reads load only these
declared siblings, reject traversal and symlink escapes, limit each container
to 64 MiB, aggregate dependency data to 512 MiB, inflated data to 32 MiB plus
the QSF header allowance, and tag blocks to 4 MiB. Data-based reads require
the caller to provide the named companions through `MetadataReadContext`.
The offset-by-offset [QSF layout](FORMAT-LAYOUTS.md#qsf--miniqsf--psf-v0x41)
documents the header, tag, and data-block fields.

Against the read-only live root-1 catalog, all 14,994 PSF-family rows across
308 source containers matched exactly, including track structure, metadata,
and authored timing. Optimized Release inspection measured 0.071 ms median and
0.090 ms p95 per member. This is a local-corpus comparison and timing, not a
cross-machine guarantee.

The SPC reader covers ID666 text/binary layouts, mixed legacy timing layouts,
and the optional xID6 chunk. It retains the exact ID666 tag region and full
xID6 chunk as separate named raw blocks, including bytes not understood by
normalized fields. Its ordered tag view includes song/game/artist/dumper/date/
comment, soundtrack/publisher, timing, muted-voice, loop-count, and mixing
items. Common fields expose title, game, artist, date, album, year, comment,
and dumper; timing is read from file metadata without rendering audio. A
malformed optional xID6 chunk is diagnosed without discarding readable ID666
values. Tagless SPCs keep ScanSong's existing projection: `Super Nintendo`,
unknown intro/loop, a 150-second play default, and zero fade. The format defines
xID6 as an aligned, extensible chunk; unrecognized data remains recoverable in
raw blocks rather than silently discarded ([SPC format reference](https://wiki.superfamicom.org/spc-and-rsn-file-format)).
SPC playback remains VGMBoy/libgme's responsibility; this parser neither
links nor instantiates the playback dependency.

The SID reader supports PSID/RSID identity fields and technical header data.
It validates the complete v1 (`0x76`-byte) or v2+ (`0x7C`-byte) fixed header
and uses the 32-byte title, author, and released fields at offsets `0x16`,
`0x36`, and `0x56`, and retains the raw header for future format-aware editing.
The `released` value remains release/copyright text rather than being coerced
into a date. SID has no standard finite play-duration field; MetaMan does not
interpret v2 extension flags as timing. This corrects the former ScanSong
reader's overlapping author/released offsets and fabricated PAL/NTSC duration
from non-duration bytes ([PSID/RSID format description](https://github.com/TheCodeTherapy/sid-player/blob/master/SIDspec.md)).
The scanner continues to publish one row per SID file; song-count and address
facts remain available in `technicalFacts`. PSID v2 and RSID v1 fixtures cover
field offsets, timing absence, raw-header retention, and truncation. The current
live CocoaSpice catalog has no `.sid` rows, so this migration has no real-file
catalog parity or performance sample yet.

The read-only live CocoaSpice catalog comparison covers roots 1 and 8: 77,326
SPC rows in 3,389 source containers. MetaMan exactly matches 76,664 saved
catalog rows. The remaining 662 row differences are checked field-by-field:
each either matches libgme's info-only output or is an ID666/xID6-backed value
whose corresponding MetaMan/libgme difference is separately source-explained.
There are zero unexplained MetaMan/libgme differences across the corpus. This
includes xID6 timing that libgme does not project; upstream leaves its intro
mapping disabled and ignores those timing items in its info-only SPC reader
([libgme SPC reader](https://github.com/libgme/game-music-emu/blob/master/gme/Spc_Emu.cpp)).
The saved catalog was only read, never modified. Optimized Release per-file
inspection measured 0.055 ms median / 0.071 ms p95 (root 1) and 0.056/0.077 ms
(root 8) for MetaMan, versus 0.038/0.052 ms and 0.040/0.052 ms for libgme
info-only. This is about 0.016-0.017 ms added at the median and 0.019-0.025 ms
at p95 in the isolated parser comparison; archive extraction is excluded, so
these are not whole-scan performance guarantees.

ScanSong uses MetaMan for SID, SPC, S98, VGM/VGZ, and PSF-family tag extraction. Its VGM
adapter keeps the English-first common fields and GD3-notes comment projection; the shared
document also exposes release date and converter. Against the current live
root-1 catalog (42,147 VGM/VGZ rows), 42,099 rows matched exactly and 48 had
only a system-label difference: MetaMan preserved the literal English GD3
value `Sega Genesis`, while the saved catalog contains alternate labels. No
other metadata, timing, or track-structure differences were found. Treat that
saved catalog as a comparison baseline, not as a current libvgm oracle. This
is a metadata-ownership extraction: the previous ScanSong VGM route was already
decoder-independent, so this change does not remove a playback-decoder
dependency.

ScanSong's SPC adapter keeps its existing schema projection: SPC date and dumper
remain available in `MetadataDocument` but are not appended to the catalog
comment. SPC playback stays with VGMBoy/libgme.

The APE reader validates descriptor and stream fields, seek-table bounds and
frame offsets, and the declared audio payload extent before deriving duration
from frame sample counts. It reads ordered APEv2 text items and common leading
ID3v2 frames; repeated and unknown text tags remain visible, while the exact
APEv2 and ID3v2 byte ranges are retained for fields not decoded by MetaMan.
Binary APEv2 items remain recoverable in the original block. APE fields expose
title, album/game, artist, date/year, genre, comment, copyright, and encoder
where present; an absent title falls back to the source filename. This path
does not invoke an audio decoder. APE playback remains owned by VGMBoy.
The read-only live root-1 catalog comparison covered all 15 APE rows from one
archive: 135 metadata/timing fields matched exactly, with zero mismatches. This
is a local-catalog parity sample, not broad corpus coverage or a paired
before/after performance benchmark. ScanSong already used this in-process
parser, so this ownership move removes no decoder dependency by itself.

The ADX reader covers CRI type 03, type 04 (including encrypted version
markers), type 05, and the distinct Monster Games header. It retains the exact
header bytes and exposes encoding, frame size, bit depth, channel count, sample
rate/count, loop state and bounds, source label, and the same
two-loop/ten-second-fade play projection previously published by ScanSong. It
does not decode audio. ScanSong performs content-aware routing: non-CRI/Monster
payloads that reuse `.adx` (including Ogg and RIFF aliases) continue to the
vgmstream inspector. Playback remains in VGMBoy. This moves metadata-parser
ownership to MetaMan but removes no playback decoder dependency from ScanSong;
the recognized ADX parser was already in-process there.

The read-only CocoaSpice root-1 differential covered 489 ADX rows in 13 source
containers. All 489 matched the saved catalog projection and all 489 matched
vgmstream exactly. Optimized Release inspection averaged 0.190 ms per row
through MetaMan versus 81.375 ms through the vgmstream CLI; the CLI figure
includes its per-file process startup. This is a local-root timing, not a
whole-scan guarantee or a before/after comparison with the former in-process
ScanSong parser.

The Atomic Planet AUS reader retains the full 32-byte header and exposes codec,
sample rate/count, channel count, both loop indicators, and raw plus effective
loop bounds. Recognized headers produce the same filename-derived title,
metadata source, and two-loop/ten-second-fade timing as the former ScanSong
reader; invalid loop ranges are excluded from timing while their source values
remain available. Non-`AUS ` payloads named `.aus` remain on ScanSong's
vgmstream fallback route. Playback remains in VGMBoy, and this ownership move
does not remove vgmstream from ScanSong because it remains required for those
aliases and other stream formats.

The read-only CocoaSpice root-1 comparison covers all 440 AUS rows in the Mega
Man Anniversary Collection archive. MetaMan, the ScanSong schema adapter, the
saved catalog, and vgmstream match exactly for all 440 rows. Optimized Release
inspection averaged 0.197 ms/file through MetaMan and 171.546 ms/file through
the vgmstream CLI, including per-file process startup. This is a local
per-file comparison, not a whole-scan guarantee.

The RIFF ATRAC3 reader accepts WAVE codec `0x0270` and the ATRAC3+ extensible
GUID. It reads `fmt `, `fact`, `smpl`, and `wsmp`, including encoder skip and
the formats' distinct loop-end conventions, and parses ordered `LIST/INFO`
tags without dropping duplicate or unknown keys. The complete RIFF header and
non-audio chunks are exposed as named raw blocks; retention is capped at 16
MiB with an explicit diagnostic if additional chunk bytes are omitted. Audio
payload bytes are not copied into metadata blocks. Nonmatching `.at3` aliases
remain on ScanSong's vgmstream fallback, and VGMBoy retains playback ownership.

The read-only CocoaSpice root-1 differential covers all 177 `.at3` rows in the
Castlevania: The Dracula X Chronicles and Silent Hill: Origins archives. MetaMan,
the ScanSong adapter, the saved catalog, and vgmstream match exactly for all
177 rows. Optimized Release inspection averaged 0.216 ms/file through MetaMan
and 411.622 ms/file through the vgmstream CLI, including per-file process
startup. This is a local per-file comparison, not a whole-scan guarantee or a
claim that the scanner no longer needs vgmstream for other formats and aliases.

The Sony MSF reader validates the 64-byte header and declared payload bounds,
retains the exact native header, and exposes the codec, channel/rate, flags,
stream name, raw loop markers, effective sample bounds, and diagnostics. It
derives PCM16 and PS-ADPCM sample counts arithmetically, applies ATRAC3 frame
sizes and encoder delay, and counts MPEG frame headers (including VBR); it
never decodes audio. Timing preserves the established vgmstream projection,
including invalid-loop cleanup and the two-loop/ten-second-fade default. The
content probe accepts Sony `MSF` signatures but leaves TamaSoft `MSF ` and
other aliases to ScanSong's vgmstream fallback. VGMBoy retains playback.

The read-only root-1 catalog differential covers 799 `.msf` files in four
archives. MetaMan plus ScanSong's schema adapter, the saved catalog, and
vgmstream match exactly across all 799 rows; the live corpus includes codecs
0, 4, 5, and 7, while focused fixtures cover codecs 1, 3, and 6. Optimized
Release inspection averaged 1.241 ms/file through MetaMan and the adapter,
versus 238.849 ms/file through the vgmstream CLI, including its per-file
process startup. This local per-file result is not a whole-scan guarantee.

The read-only root-1 SVAG differential covers all 284 rows/files in eight
archives; MetaMan plus the ScanSong adapter matches the saved catalog, the
former in-process ScanSong reader, and vgmstream exactly. All live entries use
Konami `Svag`; synthetic fixtures cover SNK `VAGm`. The same-run Release means
were 0.155 ms/file through MetaMan plus the adapter, 0.056 ms/file through the
former reader, and 236.895 ms/file through the vgmstream CLI. The neutral
document adds about 0.099 ms/file over the former reader while retaining raw
header facts; the CLI figure includes per-file process startup. These local
per-file measurements are not a whole-scan guarantee.

The SVAG reader supports both Konami `Svag` and SNK `VAGm` layouts. It retains
the Konami prefix through its `0x800` audio-data boundary (including the
optional marker at `0x400`) or the complete `0x20`-byte SNK header. Native
header values remain separately available in `technicalFacts`; invalid loop
bounds are preserved as source facts and omitted from the projected timing with
a diagnostic. Valid loops keep ScanSong's two iterations plus ten-second fade
projection. The parser never decodes PS-ADPCM, and its content probe leaves
unrelated `.svag` aliases available to other readers.

The Sony SSHD/ADS reader validates the fixed `SShd`/`SSbd` layout and the two
known containers: `ADSC` begins the inner stream at `0x08`, while the Cavia
`cavi a stream` wrapper begins it at `0x7D8`. It reads the codec, rate,
channels, interleave, raw loop values, and declared body size, applies the
decoder's body-size correction and start-padding rules, and measures timing
from encoded frames. Codec `0x01`/`0x80000001` is PCM16LE except for the
12 kHz/`0x200` video hijack, which is exposed as 48 kHz DVI IMA with an
effective `0x40` interleave; codec `0x02`/`0x10` is interleaved PS-ADPCM.
The loop-address variants, padding-frame trimming, invalid-loop cleanup, and
two-loop/ten-second-fade projection mirror the vgmstream metadata setup. No
audio is decoded. ScanSong routes only validated `.ads` payloads here and
keeps vgmstream fallback for nonmatching aliases.

The read-only root-1 comparison covered all 52 ADS rows/files across two
archives: direct MetaMan, the ScanSong adapter, the saved catalog, and a fresh
vgmstream CLI matched exactly. In the same Debug run, direct inspection
averaged 3.980 ms/file versus 152.280 ms/file for the CLI, including process
startup. This is local corpus evidence, not a whole-scan or cross-machine
performance guarantee. The byte map is in
[FORMAT-LAYOUTS.md](FORMAT-LAYOUTS.md#sony-sshd--ads).

### Headerless PlayStation MIB

The live `.mib` target is a headerless PS-ADPCM stream, not the separate
`.mib`/`.mih` bank layout. MetaMan validates the first `0x2000` bytes as PS
frames, fixes the `.mib` rate at 44,100 Hz, and scans frame markers to infer
channels, interleave, loop bounds, and sample timing. It retains the first
`0x10` bytes as a probe block and uses the filename stem for the title; no
embedded text metadata exists in this layout. Invalid probes remain eligible
for the vgmstream fallback rather than being claimed by the direct route.

The read-only root-1 comparison covered all 327 MIB rows/files across eight
archives. Direct MetaMan, the ScanSong adapter, the saved catalog, and a fresh
vgmstream `-I` inspection matched exactly for all 327 rows. In the optimized
Release run, direct inspection averaged 6.833 ms/file versus 72.767 ms/file
for the CLI, including its per-file process startup. These are local per-file
measurements, not a whole-scan or cross-machine guarantee. See the
[MIB layout](FORMAT-LAYOUTS.md#headerless-playstation-mib).

### Mixed `.adp` layouts

`.adp` is a collision extension rather than one format. ScanSong content-probes
it and routes only complete layouts to MetaMan: headerless Nintendo GameCube
DTK, or raw IMA accompanied by an exact `.adp.txth` declaration. Other
`.adp` signatures remain on the vgmstream fallback, so the direct route never
publishes a partial interpretation. In the live CocoaSpice catalog, 175 of
184 `.adp` members are Nintendo DTK streams and the remaining nine are the
Contra archive's raw mono IMA members with its hidden `.ADP.txth` sidecar.

The DTK reader preserves the first frame as a probe block and derives
`floor(fileBytes / 0x20) * 28` stereo samples at 48 kHz. The TXTH reader
supports the complete live declaration `codec = IMA`, `sample_rate`,
`channels`, and `num_samples = data_size`; it retains the original sidecar
and applies IMA's two samples per byte per channel. See the
[ADP layout](FORMAT-LAYOUTS.md#mixed-adp-layouts).

The read-only live comparison covered all 184 `.adp` rows/files: direct
MetaMan, the ScanSong adapter, the saved catalog, and fresh vgmstream matched
exactly. Release inspection averaged 0.129 ms/file directly versus 96.569
ms/file through the CLI, including per-file process startup. This is local
corpus evidence, not a whole-scan or cross-machine guarantee.

### CRI AHX

`.ahx` uses a compact CRI header followed by a fixed-bitrate MPEG/AHX payload.
MetaMan validates the `0x8000` signature, the header-relative `(c)CRI` marker,
the fixed first-frame word `FF F5 E0 C0`, mono/channel and version fields, then
derives the scanner-visible sample count from payload bytes at 160,000 bits per
second. It retains the authored sample count at `0x0C` separately instead of
silently treating that field as the current scanner duration. The filename stem
is the visible title and the established `FFmpeg format (CRI ADX)` source label
is preserved. The reader records the bounded header, an optional `AHXE(c)CRI`
footer, encryption/type facts, and does not decode audio or open the playback
path. Invalid `.ahx` aliases remain on vgmstream.

The root-1 read-only comparison covered all 11 live AHX rows/files: direct
MetaMan, the ScanSong adapter, the saved catalog, and fresh vgmstream matched
exactly. Release inspection averaged 0.160 ms/file directly versus 35.398
ms/file through the CLI, including process startup. These are local corpus
measurements, not a whole-scan or cross-machine guarantee. See the
[AHX layout](FORMAT-LAYOUTS.md#cri-ahx).

## Use

```swift
import MetaManCore

let document = try MetaManCore.read(fileURL: fileURL)
print(document.fields.date ?? "No date tag")
for tag in document.tags {
    print("\(tag.name)=\(tag.value)")
}
```

```sh
swift run --package-path MetaMan metaman read-tracks song.sap
swift run --package-path MetaMan metaman read-tracks song.hes
swift run --package-path MetaMan metaman read song.s98
swift run --package-path MetaMan metaman read song.vgz
swift run --package-path MetaMan metaman read song.minipsf
swift run --package-path MetaMan metaman read song.spc
swift run --package-path MetaMan metaman read song.sid
swift run --package-path MetaMan metaman read song.ape
swift run --package-path MetaMan metaman read song.adx
swift run --package-path MetaMan metaman read song.aus
swift run --package-path MetaMan metaman read song.at3
swift run --package-path MetaMan metaman read song.msf
swift run --package-path MetaMan metaman read song.svag
swift run --package-path MetaMan metaman read song.ads
swift run --package-path MetaMan metaman read song.mib
swift run --package-path MetaMan metaman read song.ahx
swift run --package-path MetaMan metaman read song.minigsf
swift run --package-path MetaMan metaman read song.miniqsf
```

JSON includes normalized fields, the ordered decoded tags, the original tag
block as base64 (and named raw blocks for multi-block formats such as SPC and
APE, native header blocks for ADX, AUS, MSF, and SVAG, and non-audio RIFF chunks
for ATRAC3), timing, technical facts, source encoding, and parser diagnostics.
MetaMan currently reads only; no writer or metadata mutation API
is implied. Future writers must be format-specific and preserve unknown data.

## Integration boundary

MetaMan has no dependency on ScanSong, VGMBoy, or a playback decoder. ScanSong
adapts `MetadataDocument` into its catalog schema; other clients can consume
the same library result directly. The current registry contains AY, SAP,
NSF/GBS/NSFE, HES, SNDH, KSS, S98, VGM/VGZ, SPC, SID, APE, ADX, AUS, ATRAC3,
Sony MSF, Sony SSHD/ADS, headerless PlayStation MIB, Nintendo DTK and
TXTH-described IMA ADP, CRI AHX, Konami/SNK SVAG, Sony XA, PSF/PSF2/SSF/USF/2SF, GSF/miniGSF, and
QSF/miniQSF readers.
SNDH is now fully read by MetaManCore; VGMBoy's old SNDH wrapper remains only as
a test oracle while PSGPlay remains available for playback. KSS has also moved
to MetaManCore, as have the complete GSF and QSF readers. Remaining direct
parser ownership is Core Audio standard audio in ScanSong; decoder-backed
plugin routes are not extracted by publishing only partial metadata. AY, SAP,
NSF, GBS, NSFE, HES, SNDH, KSS, and Sony XA
use the ordered result contract, including playlist repeats and native source
indices. KSS remains complete for ScanSong's existing 256-slot info-only
behavior; native KSSX track declarations are preserved as source facts, not
silently substituted for the compatibility listing. Sony XA's complete
source-sector, interleave, and timing parser now lives in MetaMan; ScanSong
retains content routing and schema projection only.
Playback plugins and decoders remain in VGMBoy regardless of where metadata
parsing lives.

The target ScanSong boundary is orchestration rather than format interpretation:
discover files, route supported sources, materialize bounded archive or
dependency context, pass sources to MetaMan, and transactionally publish the
resulting documents into the catalog. ScanSong still owns its database,
scanner UI/CLI, scheduling, and source safety; it should not grow a second set
of format parsers. OS-provided metadata such as Core Audio can remain behind a
platform adapter until MetaMan has an explicit supported abstraction for it.

MetaMan is maintained in the VGMMan family repository. ScanSong and other
family clients resolve it from the shared checkout, so its source and reader
contracts move with the rest of the application family. An independent package
publication is only needed if an external client requires a separate release
channel.
