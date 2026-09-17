# UAC Wrapper Format

## Scope

UAC (Universal Audio Container) is a per-game package for the annual
`YYYY/<ConsoleName>` collection. It
groups original, lossless playable files and their variants under one logical
game, while keeping source provenance and metadata in a bounded manifest that
is compressed independently when doing so reduces its stored size.
It is a package format, not an audio codec or a replacement for TAR/Zstandard.

## Binary Layout (Version 1)

The file begins with a standard Zstandard skippable frame containing the UACM
header and either a bounded UTF-8 JSON manifest or a small independent
Zstandard frame containing that JSON. A UAC reader decodes only this metadata
frame; it does not decompress the TAR/audio payload to inspect metadata. The
following payload is an ordinary TAR byte stream compressed as a sequence of
independently compressed Zstandard frames, followed by the Zstandard
seek-table skippable frame. The manifest's `tarDataOffset` values map members
to uncompressed byte ranges in the TAR stream; the seek table maps those
ranges to compressed frames.

A normal Zstandard decoder skips the UAC metadata frame, decompresses the
concatenated Zstandard frames, and skips the trailing seek table. Consequently
`zstd -dc game.uac | tar ...` still lists and extracts the complete ordinary
TAR stream. The UAC reader can instead read the manifest and seek table, then
decompress only frames needed for a selected member range.

| Offset | Size | Meaning |
| --- | ---: | --- |
| 0 | 4 | Zstandard skippable-frame magic `0x184D2A55` (little-endian bytes `55 2A 4D 18`) |
| 4 | 4 | Skippable payload byte length `N`, unsigned little-endian |
| 8 | 4 | UAC metadata marker `UACM` |
| 12 | 2 | UAC major version, `1` |
| 14 | 2 | UAC minor version, `0` |
| 16 | 32 | SHA-256 of the decoded UTF-8 JSON manifest bytes |
| 48 | variable | If the next bytes are `ZJ01`, a 4-byte little-endian decoded JSON length follows, then one standard Zstandard frame containing the JSON. Otherwise, this is the legacy raw UTF-8 JSON manifest. |
| `8 + N` | remaining file | Concatenated Zstandard frames containing TAR bytes, then the seek table |

New writers compress the JSON at Zstandard level 3 only when the complete
`ZJ01` marker, decoded-length field, and compressed frame are smaller than the
raw JSON; otherwise, they use the raw representation. This prevents metadata
encoding from ever increasing the manifest's stored byte count. The SHA-256
always covers the decoded JSON, so both encodings have the same logical
manifest identity. The outer skippable frame remains opaque to ordinary
Zstandard decoders, which continue directly to the TAR payload.

The seek table is the final skippable frame in the payload. Its magic is
`0x184D2A5E`; its entries record each compressed frame's compressed and TAR
byte counts, with optional frame checksums; its footer ends in
`0x8F92EAB1`. The UAC metadata frame remains outside this payload, so payload
frame offsets are relative to the first compressed TAR frame.

The decoded manifest is capped at 16 MiB by the current reader; the encoded
skippable-frame body is bounded by that limit plus the small `ZJ01` prefix.
Compressed readers must validate the decoded-size bound before allocation and
require the decompressor to produce exactly the declared byte count; the
current reader contract caps manifest-decoder memory at 32 MiB. Metadata
objects support arbitrary JSON values and namespaced extension maps; the byte
limit protects readers from hostile or accidental unbounded allocations, not
from a fixed vocabulary. The SHA-256 detects manifest corruption; it is not a
signature or proof of publisher authenticity.

## Manifest Contract

The required top-level fields are `manifestVersion` (`1`), `packageID`,
`payload`, `game`, `variants`, `members`, `playlists`, `sources`,
`transformations`, and `extensions`.

- `game` contains the logical game ID, canonical title/system, canonical
  release IDs, and extensible metadata.
- Each `variant` groups a version, alternate, regional release, or other
  distinction and may carry its own canonical release IDs and metadata. A
  variant is not an automatic ranking or deletion decision.
- Each `member` records the path inside the UAC, original member name, optional
  variant and source references, role, format, byte size, raw-member BLAKE3,
  optional playable-payload BLAKE3, additional scoped/profiled `hashes`, and
  extensible metadata. Seekable payloads also require `tarDataOffset`, the
  offset of the member's first data byte in the decompressed TAR stream (not
  the TAR header offset).
- Each `playlist` is an ordered, UAC-native list of `targetMemberPath` pointers
  and optional target-member hashes. Entries retain raw source lines/context,
  format tags, title/artist, track index, and format-specific duration, loop,
  fade, repeat, and stop values without assuming shared units. If an original
  M3U/M3U8 exists, `originalMemberPath` points to its ordinary TAR member; its
  original bytes remain unchanged for exact unpacking.
- Each `source` records the source collection/set and original package identity
  (including its BLAKE3 where known). A source URL is provenance; local absolute
  file paths are not identity fields.
- Each `transformation` is a per-game ledger entry: operation class, source
  member paths and raw/stream BLAKE3 inputs, output member paths and hashes,
  tool/version, timestamp, optional rationale, and extensible details. Common
  operation classes include `rename`, `tag-normalization`, `recompress`,
  `transcode`, `playlist-repair`, `duplicate-prune`, `metadata-harvest`, and
  `package`; new classes are allowed. Every input source must exist, and every
  output must resolve to a manifest member with the same raw BLAKE3.
- The UACMan wrapper CLI adds a `package` transformation for each linked source,
  mapping the selected source members and hashes to their byte-identical UAC
  members. Other transformation entries describe prior or explicit content
  operations; packaging does not imply that member bytes were rewritten.
- New payloads use `payload.format` `tar+zstd-seekable` and a compression
  profile `uac-zstd-seekable-level-<L>-frame-<N>-v1`, where `L` is 0–22 and
  `N` is the maximum decompressed TAR bytes per independent frame (at most
  64 MiB for current UAC readers). The current
  UACMan wrapper defaults to level 3 and 4 MiB frames for the first SPC player
  replacement. This is a quick-build starting profile, not a format-wide
  optimum; level 19 remains available for measured comparisons. Level 0 selects
  the Zstandard default (currently equivalent to level 3); 20–22 are ultra
  levels. The
  legacy seekable profile `uac-zstd-seekable-3-v1` and legacy sequential
  `tar+zstd` profile remain readable, but the latter has no efficient member
  seek. `payload.encoderVersion` records the encoder build and is required;
  `payload.blake3` identifies the exact compressed payload bytes, including
  the seek table.
- `member.blake3` identifies exact stored member bytes. `streamBlake3` is a
  compatibility shortcut for a named playable-payload profile; it is not a
  rendered-audio hash. In AudioMan's VGM collection profile, `.vgz` is hashed
  after gzip decompression; other playable formats hash their complete native
  member bytes, including headers/tags. No command-stream normalization or emulation
  render hash is generated. Additional hashes belong in `hashes[]` with
  explicit scope, algorithm, and profile. A digest proves equality only for
  the exact byte scope/profile: it does not prove correct track identity, dump
  offset, timing, or completeness. Valid alternate captures may have different
  bytes; retain multiple known hashes keyed by identity/profile instead of
  assuming one universal “correct” digest.
- The structural envelope is fixed and versioned, with a small stable set of
  typed cross-format fields; optional agreed common fields live in each
  object's `metadata` map. Format-specific and user-defined fields remain
  open-ended typed JSON in namespaced `extensions` maps at game, variant,
  member, and source level; do not require a full tag-vocabulary brainstorm
  before adding them. Promote a field into the universal core only when its
  meaning and units are stable across formats. Unknown extension values must
  survive read/write unchanged. MetaManCore owns native-tag parsing. The
  UACMan creation-time bridge consumes its structured projection; the wrapper
  does not implement or duplicate format parsers. UAC catalog scans trust the
  stored manifest instead of re-reading member tags.

Member paths are relative POSIX paths. Variant members are isolated below
`variants/<variantID>/`; game-wide files use `assets/` or `shared/`. Paths must
not be absolute, contain traversal components, collide, or escape their
variant root. TAR payloads contain only regular file members listed by the
manifest; links, devices, and unlisted payload members are invalid.

## Preservation and Compression

The UAC layer must not retag, transcode, normalize, or rewrite member bytes.
TAR member extraction reproduces every listed input file byte-for-byte.
Original filenames and relative companion layout are preserved within the
variant namespace, so M3U pointers and decoder dependencies remain together.
The structured manifest playlist is the UAC playback list; the original M3U
member is retained as byte-exact reversible evidence, not required for UAC-aware
playback. PNGs, M3U/M3U8, documentation, and other files are ordinary typed
members and may carry arbitrary metadata.

V1 uses the existing TAR and Zstandard formats internally. The UACMan wrapper
writer emits members in stable path order, normalizes TAR ownership/mode/time
fields, supplies each independent frame's exact input size to Zstandard, and
appends the standard seek table. Its default maximum frame size is 4 MiB;
boundaries are fixed-size chunks, not member-aligned. Smaller frames reduce
the maximum over-read/decompression work for a small request, but may sharply
reduce compression where content repeats between tracks. Exact compressed-byte
reproducibility is guaranteed only for the same writer and encoder build; raw
member bytes and their hashes are the preservation invariant. The core reader
caps one frame and its total decompressed frame cache at 64 MiB; this is an
application safety limit below the seek-table format's theoretical maximum.
Updating metadata
requires a new header/manifest while copying the compressed payload bytes
unchanged—never recompress solely to edit metadata.

`UACContainer.manifestJSON` exposes the decoded manifest bytes without a
model-based JSON re-encode, so editors can retain unknown future keys.
`UACContainerWriter.rewriteManifest` validates a source package and new
manifest, writes to a new destination, and copies the source payload range
directly from its current offset. It does not create an intermediate payload
file or decompress/recompress the TAR stream; callers can verify the new
container and then perform their own atomic replacement policy.

The manifest itself uses compact UTF-8 JSON and an independent Zstandard
frame when that is smaller than raw JSON including its codec prefix. Metadata
compression does not alter TAR offsets or payload hashes. `UACWrapperCore`
keeps the codec injected: the host supplies a bounded frame decoder (and the
writer a compressor), while the Python `uacman` CLI uses the Zstandard command
line tool with bounded output and decoder-memory limits. A decoded manifest
should be cached for the lifetime of an open container so repeated field
access pays no repeated decompression cost.

Member data offsets must come from the completed TAR writer/index, not a
`512-byte header` assumption: PAX metadata records can precede file data. TAR
creation must suppress macOS-generated AppleDouble records unless an AppleDouble
file is an intentional source member. The reader validates the UAC metadata
frame and seek-table bounds/counts, manifest references and safe paths, and
every indexed member range against the total decompressed TAR length. It reads
no audio frame data for this validation. Payload integrity and member BLAKE3
are verified during an explicit full check or read.

The seekable Zstandard API supports arbitrary decompressed byte-range reads
through a seekable backing source. `UACSeekableMemberFile` exposes an indexed
member as a read-only virtual byte file: it reads only intersecting compressed
frames, caches at most four by default and no more than 64 MiB total in memory,
and writes no extracted audio to disk. Its injected frame decoder must validate any optional seek-table
checksum. CocoaSpice injects a bounded host Zstandard decoder for compressed
manifests and seekable payload frames. For SPC, CocoaSpice reads the selected
member through this virtual file and supplies the bounded member bytes to
libgme's in-memory open API; decompressed SPC bytes are not written to playback
cache. Other formats whose decoders require filesystem paths use the existing
selected-entry materialization route. The UACMan wrapper CLI accepts a JSON
recipe and can invoke MetaManCore through UACManMetadataCLI. SPC uses its
soundtrack-aware projection; other single-track MetaMan formats use the common
member projection. Track-aware results are rejected instead of flattened until
UAC defines their mapping. The wrapper does not contain native format parsers.
CLI unpack restores original members and writes `manifest.json` by default; it
does not synthesize an M3U when no original playlist member was included.

## Ownership and Safety

- `UACWrapperCore` in `UACMan/Wrapper` owns the bounded manifest reader,
  seek-table validation, TAR-range-to-frame mapping, and byte-preserving
  payload copy operations. The TAR writer and Zstandard codec remain injected
  or owned by the package builder.
- The UACMan wrapper owns package creation, inspection, extraction, and the
  source/member mapping encoded in the manifest. AudioMan owns the collection
  workflow and supplies its selected source records and recipe.
- CocoaSpice owns presentation and queue policy; it consumes manifest metadata
  and delegates archive materialization to FrontendCore.
- MetaManCore owns UAC package/member metadata documents and consumes the
  shared UACWrapperCore parser. ScanSong projects those documents and owns
  catalog publication; player apps do not write catalog records.
- The outer UAC and member hashes are not a license to delete original source
  packages or source-state manifests.

Reject unknown major versions, wrong UAC skippable-frame markers, truncated or
oversized manifests, invalid digests, unsupported payload profiles,
duplicate/unsafe paths, missing variant/source references, malformed member
hashes, and broken transformation references. Do not fall back to treating an
invalid `.uac` as TAR, ZIP, or standalone audio.

## Files

- `Wrapper/Sources/UACWrapperCore/UACContainerReader.swift`
- `Wrapper/Sources/UACWrapperCore/UACContainerWriter.swift`
- `Wrapper/Sources/UACWrapperCore/UACSeekableFormat.swift`
- `Wrapper/Sources/UACWrapperCore/UACSeekableMemberFile.swift`
- `Wrapper/python/uacman.py`
- `Wrapper/Tests/UACWrapperCoreTests/UACContainerReaderTests.swift`
- `Wrapper/python/tests/`
