# MetaMan

MetaMan is a decoder-independent metadata-reading library for game-audio and
other media files. Its reusable product is `MetaManCore`; the `metaman` command
is a thin JSON interface for scripting and support work. Applications should
import the library rather than shelling out to the CLI.

MetaMan currently has complete S98, VGM/VGZ, PSF-style tag, SPC ID666/xID6,
SID PSID/RSID, APE, and CRI/Monster ADX readers. The S98 reader handles
header/device information, the full v3 tag block (including
arbitrary and repeated keys), legacy pre-v3 titles, and timing from the
register-command stream. The VGM reader handles the common header, timing
fields, gzip-compressed VGZ input, and the complete standard GD3 field
sequence. These readers do not instantiate a playback core. Unknown fields,
both GD3 language variants, and original tag bytes remain available to clients.

| Format | Read path | Metadata / timing | Write support |
| --- | --- | --- | --- |
| S98 v0-v3 | Direct header, tag-block, device-table, and command-stream parser | Ordered raw tags, normalized common fields, technical header facts, and stream timing | Not implemented |
| VGM / VGZ | Direct 64-byte header and GD3 parser; bounded gzip inflate for compressed input | All 11 ordered GD3 fields (plus future extras), original-language values, release date, converter, notes, header facts, and 44.1 kHz sample timing | Not implemented |
| PSF / PSF2 / SSF / USF / 2SF | Direct PSF-style header and `[TAG]` footer parser; no playback core | Ordered tags including duplicates and unknown keys, raw footer bytes, normalized identity, authored length/fade, and console identity by extension | Not implemented |
| SPC | Direct text/binary ID666 header and xID6 chunk parser; no playback emulator | Ordered metadata, dump date, dumper/emulator facts, soundtrack fields, native timing, and separately retained ID666/xID6 source blocks | Not implemented |
| SID (PSID / RSID) | Direct fixed-header parser; no playback core | Title, author, release text, technical header facts, and retained raw header; no duration inferred from flags | Not implemented |
| APE | Direct descriptor, seek-table, APEv2, and leading ID3v2 parser; no audio decoder | Ordered text tags, normalized common fields, exact ID3v2/APEv2 blocks, technical header facts, and sample-count duration | Not implemented |
| CRI / Monster ADX | Direct CRI type-03/04/05 and Monster Games header parser; no audio decoder | Filename-derived title, source label, exact header bytes, sample/channel/loop facts, and sample-derived loop/play timing | Not implemented |

This is a library first, not a CLI-only tool. The `metaman` executable is an
optional JSON frontend; CocoaSpice, ScanSong, and future clients can consume
`MetaManCore` directly. File reading and tag interpretation stay together in
the core, while clients own their transport, catalog, and UI concerns.

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
used to locate that footer remain available. GSF and QSF are intentionally not
included in this generic reader because their complete scanner routes also
validate format-specific blocks and dependency chains.

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
swift run --package-path MetaMan metaman read song.s98
swift run --package-path MetaMan metaman read song.vgz
swift run --package-path MetaMan metaman read song.minipsf
swift run --package-path MetaMan metaman read song.spc
swift run --package-path MetaMan metaman read song.sid
swift run --package-path MetaMan metaman read song.ape
swift run --package-path MetaMan metaman read song.adx
```

JSON includes normalized fields, the ordered decoded tags, the original tag
block as base64 (and named raw blocks for multi-block formats such as SPC and
APE), timing, technical facts, source encoding, and parser
diagnostics. MetaMan currently reads only; no writer or metadata mutation API
is implied. Future writers must be format-specific and preserve unknown data.

## Integration boundary

MetaMan has no dependency on ScanSong, VGMBoy, or a playback decoder. ScanSong
adapts `MetadataDocument` into its catalog schema; other clients can consume
the same library result directly. The current registry contains S98, VGM/VGZ,
SPC, SID, APE, ADX, and PSF/PSF2/SSF/USF/2SF readers. Remaining direct-parser
ownership is split between `VGMBoyFormatDataCore` (AY, NSF/GBS/NSFE, SAP, and
HES), `VGMBoySNDH` (SNDH), and ScanSong (KSS, specialized GSF/QSF, content-aware
ATRAC3/AUS/Sony MSF/SVAG/XA, and Core Audio standard audio). These are the
current migration surface; decoder-backed plugin routes are not extracted by
publishing only partial metadata. Multi-track families need a track-aware
neutral document contract before they can share MetaMan without flattening
subsong metadata. Playback plugins and decoders remain in VGMBoy regardless
of where metadata parsing lives.

This repository currently has no Git remote. ScanSong consumes it as a sibling
path dependency; independent checkouts and other clients need a published
MetaMan repository (or a package-registry release) before they can resolve this
shared dependency outside the local project family.
