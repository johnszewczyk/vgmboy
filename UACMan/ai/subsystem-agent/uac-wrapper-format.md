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

The decoded manifest is capped at 16 MiB by the current reader, and the
current reader accepts at most 100,000 member records; the encoded
skippable-frame body is bounded by that limit plus the small `ZJ01` prefix.
Compressed readers must validate the decoded-size bound before allocation and
require the decompressor to produce exactly the declared byte count; the
current reader contract caps manifest-decoder memory at 32 MiB. Metadata
objects support arbitrary JSON values and namespaced extension maps; the byte
limit protects readers from hostile or accidental unbounded allocations, not
from a fixed vocabulary. The SHA-256 detects manifest corruption; it is not a
signature or proof of publisher authenticity.

## Manifest Contract

The required top-level fields are `manifestVersion` (`1` or `2`), `packageID`,
`payload`, `game`, `variants`, `members`, `playlists`, `sources`,
`transformations`, and `extensions`.

The envelope header remains binary version 1.0. `manifestVersion` versions the
JSON contract independently: new writers emit manifest version 2, while
current readers retain support for version 1 packages. Older readers that only
know manifest version 1 reject new version-2 packages; ship updated consumers
before distributing newly packed files.

- `game` contains the logical game ID, canonical title/system, canonical
  release IDs, and extensible metadata. Common attachment pointers belong in
  this metadata map and resolve to ordinary members. For example,
  `game.metadata.cover_front` and `cover_back` may each be one reference object
  or an array of references shaped as `{"memberPath":"scans/front.png","mediaType":"image/png"}` for a single-variant package.
  Arrays retain multiple scans for one role. `game.metadata.cue_sheet` may
  point to a source `.cue` member; `game.metadata.documents` may similarly
  list notes, text files, Markdown, and other documentation. These open JSON
  fields do not change member bytes. References should resolve to manifest
  member paths, and image/document payloads remain independently hashed members.
  When source records establish one clear collection and set, the package may
  expose distinct scalar tags `game.metadata.setCollection`,
  `game.metadata.setName`, and `game.metadata.setUrl`. Optional legacy and archive
  links use `setLegacyUrl` and `setArchiveUrl`. A set date is included only when
  the source provides a trustworthy date. These are package-level tags, not
  track tags; do not nest them under a `set` object or bundle them into an array.
  The complete source records remain authoritative in `sources[]`; omit the
  projection when sources conflict or no trustworthy URL is available.
  Project2612 uses `setUrl` for the current VGMRips system listing,
  `setLegacyUrl` for the original `project2612.org` address, and `setArchiveUrl`
  for its Wayback snapshot. Project2612 is defunct; the VGMRips directory link is
  not a claim that every historic pack was migrated one-to-one. The `enrich-sets`
  command adds these tags to existing packages as a manifest-only rewrite and
  byte-copies the compressed payload; it runs in dry-run mode unless `--apply`
  is supplied.
  Redump packages may also cite derived-output and metadata-association records.
  When a `redump-disc-archive` source is present, that record supplies the set
  projection; the Archive.org download URL must identify the same item as
  `setName`, and the projected URL is the item's `/details/<identifier>` page.
  New writers add `game.metadata.containedContainerVersions` only when SPC or
  VGM members are present. The inventory includes only those formats and their
  version-count groups; it does not include a mixed-version flag. UACMan records
  format facts but leaves mixed-version review to set-level consumers such as
  AudioMan. SPC version is read from header byte `0x24`; the signature's textual
  version is retained separately because source files may disagree between
  those two facts. Each SPC member exposes
  `metadata.spcVersion`, `metadata.spcVersionByte`, and
  `metadata.spcHeaderVersion` for direct access. VGM detection reads `.vgm`
  headers, including gzip-wrapped bytes when a caller supplies them under a
  `.vgm` name. The generic pack boundary rejects `.vgz` members because the
  nested gzip wrapper reduces the effectiveness of the outer Zstandard layer.
  Set-specific consumers such as AudioMan may add required
  `metadata.sub-container-version` tags and mixed-version critical flags; the
  wrapper does not impose those project policies.
- Each `variant` groups a version, alternate, regional release, or other
  distinction and may carry its own canonical release IDs and metadata. A
  variant is not an automatic ranking or deletion decision.
- Each `member` records the path inside the UAC, original member name, optional
  variant and source references, role, format, byte size, raw-member BLAKE3,
  optional playable-payload BLAKE3, additional scoped/profiled `hashes`, and
  extensible metadata. Seekable payloads also require `tarDataOffset`, the
  offset of the member's first data byte in the decompressed TAR stream (not
  the TAR header offset).
  New writers add `crc32-iso-hdlc` records to `hashes[]` for raw members and
  playable payloads. Playable-payload records also include `sha1` and `md5`,
  alongside `blake3-256`, so a stream can expose the four common digest
  algorithms without duplicating a separate metadata checksum tag. For an
  ordinary untransformed member such as SPC, the playable-payload digests are
  over the complete stored member bytes; a format with a distinct playable
  projection hashes that declared profile instead. Verifiers check every
  supported hash record whose scope/profile they can reproduce.
  Hash-record digests are hexadecimal and may use either case for compatibility
  with existing CRC32 writers; `blake3-256` values remain canonical lowercase.
  For audio members, `metadata.loop` is the authoritative sample loop object
  when present: `mode` (`forward`), `startSamples`, `endSamples` (exclusive),
  `sampleRateHz`, `repeat` (`forever` or a nonnegative integer), and `source`.
  Consumers must not fill a missing UAC loop by rereading enclosed member tags;
  UAC metadata wins over FLAC/APE comments. The exact native tags remain in
  the member bytes and may be retained as provenance, but they are not a
  second competing playback instruction.
- Each `playlist` is an ordered, UAC-native list of `targetMemberPath` pointers
  and optional target-member hashes. Entries retain raw source lines/context,
  format tags, title/artist, track index, and format-specific duration, loop,
  fade, repeat, and stop values without assuming shared units. An entry with
  `entryKind: "subsong"` maps one logical decoder track inside a playable
  member; its nonnegative decimal `trackIndex` is the decoder's source track
  index. Multiple subsong entries can point at one unchanged NSF/NSFE/GBS
  member, and `extraFields.metaManMetadata` retains the full per-track MetaMan
  projection. Subsong entries expand as separate UAC metadata tracks; ordinary
  `file` playlist entries do not. If an original M3U/M3U8 exists,
  `originalMemberPath` points to its ordinary TAR member; its original bytes
  remain unchanged for exact unpacking.
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
- A canonical derived CD/stream audio member may use Monkey's Audio (APE) at
  the selected maximum/insane compression profile. FLAC remains a readable
  compatibility input, but a FLAC-to-APE conversion is a PCM-preserving
  transcode and must be recorded as a `transcode` transformation. A decoded
  XA stream can be stored in APE without sample loss; APE cannot reconstruct
  the original XA ADPCM sectors, interleave, headers, or cue layout. Retain
  the source BIN/XA/CUE members or their immutable source package and hashes
  whenever source-level reconstruction matters.
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
  rendered-audio hash. The current `uac-playable-payload-v1` profile hashes
  `.vgz` after gzip decompression; other playable formats hash their complete
  native member bytes, including headers/tags. The older
  `audioman-playable-payload-v1` profile remains valid as a historical hash
  label on existing packages. No command-stream normalization or emulation
  render hash is generated. Hashes are grouped in `hashes[]` records with an
  explicit scope, algorithm, and profile rather than exposed as four unrelated
  tag names. CRC32 supports fast lookups; BLAKE3 remains the content identity
  hash. A digest proves equality only for the exact byte scope/profile: it does
  not prove correct track identity, dump offset, timing, or completeness. Valid
  alternate captures may have different bytes; retain multiple known hashes
  keyed by identity/profile instead of assuming one universal “correct” digest.
- Stream identity is format-profiled, not universal. A `raw-member-v1` profile
  is authoritative when the stored member is itself the canonical source
  stream, as with an extracted CD-XA file. A `decoded-pcm-v1` profile is a
  separately computed hash of declared PCM parameters and decoded samples,
  as with a lossless APE/FLAC transcode. A `rendered-playback-v1` profile is
  an emulator or decoder output and must name the renderer, version, settings,
  sample format, rate, channel layout, and render duration. Formats without a
  reproducible stream projection may omit stream hashes entirely. Never emit
  an empty stream hash, and never call a raw file hash a rendered-audio hash.
- The structural envelope is fixed and versioned, with a small stable set of
  typed cross-format fields. UAC uses one shared metadata vocabulary across
  packages, tools, and consumers: producers must reuse the canonical field
  name, location, type, and meaning defined in this contract for a shared
  concept, and must not emit synonymous aliases. For example, the canonical
  system identity is `game.console`; do not also write the same value as
  `game.metadata.system` or `platform`. Package set tags use
  `game.metadata.setCollection`, `setName`, `setUrl`,
  `setLegacyUrl`, and `setArchiveUrl`, while source-specific identifiers remain
  in their documented `sources[]` fields. Common attachment keys include
  `game.metadata.cover_front`, `cover_back`, `cue_sheet`, and `documents`.
  Format-specific and genuinely user-defined fields remain open-ended typed
  JSON in namespaced `extensions` maps at game, variant, member, and source
  level. Do not use a custom extension as a second spelling for a shared
  concept. Preserve unrecognized extension values unchanged. Promote a field
  into this shared vocabulary only when its meaning, location, type, and units
  are stable across formats; update this contract before producers emit it as
  a common field. MetaManCore owns native-tag parsing. The UACMan creation-time
  bridge consumes its structured projection; the wrapper does not implement
  or duplicate format parsers. UAC catalog scans trust the stored manifest
  instead of re-reading member tags. Native source tags and member bytes remain
  unchanged; normalization applies only to the UAC manifest projection, while
  MetaMan's retained raw/ordered metadata preserves source spelling and order.

Member paths are relative POSIX paths. Manifest version 1 places every
variant member below `variants/<variantID>/`. Version 2 uses the source-relative
member path when the package declares one variant; when it declares multiple
variants, members remain isolated below `variants/<variantID>/`. New writers
emit the flat source-relative layout for a one-variant package. Readers accept
both layouts, so existing version-1 packages need no rewrite. Game-wide files
without a `variantID` use `assets/` or `shared/`. Paths must not be absolute,
contain traversal components, or collide. TAR payloads contain only regular
file members listed by the manifest; links, devices, and unlisted payload
members are invalid. Roles are
open strings: playable streams, playlist files, image scans, cue sheets, and
documentation are all members, but only `playable`/`track` roles generate
song rows in MetaMan and ScanSong. PNG, `.cue`, `.txt`, and `.md` source files
are included as ordinary byte-exact members by the packer; they are not
discarded as sidecars.

## Preservation and Compression

The UAC layer must not retag, transcode, normalize, or rewrite member bytes.
TAR member extraction reproduces every listed input file byte-for-byte.
Original filenames and relative companion layout are preserved, so M3U
pointers and decoder dependencies remain together. Multi-variant packages use
the variant namespace to prevent same-path collisions; single-variant packages
do not add a synthetic `variants/original/` directory.
The structured manifest playlist is the UAC playback list; the original M3U
member is retained as byte-exact reversible evidence, not required for UAC-aware
playback. PNGs, CUE sheets, M3U/M3U8, documentation, and other files are
ordinary typed members and may carry arbitrary metadata. Packaging a cue sheet
preserves it and its audio-member references; current UAC players do not
interpret an external CUE to split one APE or FLAC member into virtual tracks.
Cue-aware playback requires an explicit player feature that resolves cue file
references to UAC members and applies its indexes to decoder seeking.

There is no format-wide total package-byte limit. Practical bounds are the
reader's 16 MiB manifest and 100,000-member limits, the 64 MiB maximum
decompressed Zstandard frame accepted by current readers, the seek-table's
32-bit entry framing, filesystem/file-offset limits, and available storage.
These are explicit reader and implementation bounds, not a fixed small-media
assumption.

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
soundtrack-aware projection; single-track formats use the common member
projection, and track-aware formats use ordered subsong playlist entries. A
track-aware result without unique nonnegative decoder indexes fails the
harvest rather than being flattened. A successful generic MetaMan harvest
defaults that member's role to `playable`; an explicit recipe role remains
authoritative. The bridge accepts MetaManCore's advertised source formats,
excluding UAC itself. Standard audio and APE metadata reads allow members up to
1 GiB; the general source-member limit remains 64 MiB. The wrapper does not
contain native format parsers.
CLI unpack restores original members and writes `manifest.json` by default; it
does not synthesize an M3U when no original playlist member was included.

## Ownership and Safety

- `UACWrapperCore` in `UACMan/Wrapper` owns the bounded manifest reader,
  seek-table validation, TAR-range-to-frame mapping, and byte-preserving
  payload copy operations. The TAR writer and Zstandard codec remain injected
  or owned by the package builder.
- The UACMan project under VGMMan owns package creation, inspection,
  extraction, the wrapper contract, and the source/member mapping encoded in
  the manifest. AudioMan is one downstream operator: it chooses source sets
  and recipes and invokes UACMan's CLI; it does not own or implement UAC.
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
- `Wrapper/Sources/UACWrapperCore/UACManifest.swift`
- `Wrapper/Sources/UACWrapperCore/UACManifestValidator.swift`
- `Wrapper/Sources/UACWrapperCore/UACContainerWriter.swift`
- `Wrapper/Sources/UACWrapperCore/UACSeekableFormat.swift`
- `Wrapper/Sources/UACWrapperCore/UACSeekableMemberFile.swift`
- `Wrapper/python/uacman.py`
- `Wrapper/Tests/UACWrapperCoreTests/UACContainerReaderTests.swift`
- `Wrapper/python/tests/`
