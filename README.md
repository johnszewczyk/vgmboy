# MetaMan

MetaMan is a decoder-independent metadata-reading library for game-audio and
other media files. Its reusable product is `MetaManCore`; the `metaman` command
is a thin JSON interface for scripting and support work. Applications should
import the library rather than shelling out to the CLI.

The first complete format implementation is S98. It reads header/device
information, the full v3 tag block (including arbitrary and repeated keys),
legacy pre-v3 titles, and timing from the register-command stream. It does not
instantiate a playback core. A UTF-8 v3 `DATE` is retained as a full string and
preferred for normalized `date`; `YEAR` remains independently available.
Unknown fields and original tag bytes are retained for diagnostics and future
editor work.

| Format | Read path | Metadata / timing | Write support |
| --- | --- | --- | --- |
| S98 v0-v3 | Direct header, tag-block, device-table, and command-stream parser | Ordered raw tags, normalized common fields, technical header facts, and stream timing | Not implemented |

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
```

JSON includes normalized fields, the ordered decoded tags, the original tag
block as base64, timing, technical facts, source encoding, and parser
diagnostics. MetaMan currently reads only; no writer or metadata mutation API
is implied. Future writers must be format-specific and preserve unknown data.

## Integration boundary

MetaMan has no dependency on ScanSong, VGMBoy, or a playback decoder. ScanSong
adapts `MetadataDocument` into its catalog schema; other clients can consume
the same library result directly. Formats move into MetaMan as complete
readers, with their methodology and evidence added to the table above. The
current registry contains S98 only; other ScanSong readers have not yet been
migrated.
