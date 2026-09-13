# MetaMan

MetaMan is a decoder-independent metadata-reading library for game-audio and
other media files. Its reusable product is `MetaManCore`; the `metaman` command
is a thin JSON interface for scripting and support work. Applications should
import the library rather than shelling out to the CLI.

MetaMan currently has complete S98 and VGM/VGZ readers. The S98 reader handles
header/device information, the full v3 tag block (including arbitrary and
repeated keys), legacy pre-v3 titles, and timing from the register-command
stream. The VGM reader handles the common header, timing fields, gzip-compressed
VGZ input, and the complete standard GD3 field sequence. Neither reader
instantiates a playback core. Unknown fields, both GD3 language variants, and
original tag bytes remain available to clients.

| Format | Read path | Metadata / timing | Write support |
| --- | --- | --- | --- |
| S98 v0-v3 | Direct header, tag-block, device-table, and command-stream parser | Ordered raw tags, normalized common fields, technical header facts, and stream timing | Not implemented |
| VGM / VGZ | Direct 64-byte header and GD3 parser; bounded gzip inflate for compressed input | All 11 ordered GD3 fields (plus future extras), original-language values, release date, converter, notes, header facts, and 44.1 kHz sample timing | Not implemented |

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

ScanSong uses MetaMan for both VGM and S98. Its VGM adapter keeps the
English-first common fields and GD3-notes comment projection; the shared
document also exposes release date and converter. Against the current live
root-1 catalog (42,147 VGM/VGZ rows), 42,099 rows matched exactly and 48 had
only a system-label difference: MetaMan preserved the literal English GD3
value `Sega Genesis`, while the saved catalog contains alternate labels. No
other metadata, timing, or track-structure differences were found. Treat that
saved catalog as a comparison baseline, not as a current libvgm oracle. This
is a metadata-ownership extraction: the previous ScanSong VGM route was already
decoder-independent, so this change does not remove a playback-decoder
dependency.

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
```

JSON includes normalized fields, the ordered decoded tags, the original tag
block as base64, timing, technical facts, source encoding, and parser
diagnostics. MetaMan currently reads only; no writer or metadata mutation API
is implied. Future writers must be format-specific and preserve unknown data.

## Integration boundary

MetaMan has no dependency on ScanSong, VGMBoy, or a playback decoder. ScanSong
adapts `MetadataDocument` into its catalog schema; other clients can consume
the same library result directly. The current registry contains S98 and
VGM/VGZ. Other ScanSong readers have not yet been migrated.

This repository currently has no Git remote. ScanSong consumes it as a sibling
path dependency; independent checkouts and other clients need a published
MetaMan repository (or a package-registry release) before they can resolve this
shared dependency outside the local project family.
