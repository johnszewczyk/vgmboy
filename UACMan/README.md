# UACMan

UACMan is the native macOS browser/editor for `.uac` packages, owned entirely
by the VGMMan project. It browses collection folders, reads manifests without
decompressing payloads, and lists every package member: playable streams,
images, cue sheets, and documents. The metadata workspace edits package-level and
per-member metadata, including asset metadata, while selection can target
individual members. MetaMan remains the CLI backed by MetaManCore; UACMan is its
user interface for UAC collection browsing and manifest editing. AudioMan can
invoke the UACMan CLI for its own source-set workflow but owns no UAC code or
format contract.
The collection grid and metadata workspace are rendered by a bundled local
WKWebView workspace. Swift remains responsible for file access, prompts,
validation, and package writes; the app launcher embeds the SwiftPM web-resource
bundle in the `.app` so the same UI loads from LaunchPad and command-line runs.
The workspace is organized into six pages: **Tracks** is a dense fixed-width,
spreadsheet-style audio-only table with tag columns. Its single heading line keeps
the shown/audio count and right-aligned filter beside **Tracks**, and every column
header sorts the visible rows. Its first column is checkbox-only, with an all/none
checkbox in its header. **Package Tags** contains set-level fields and a separate
attachment list; **Track Tags** edits the selected track; **Technical** is a
dedicated table for hashes, source facts, and diagnostics; **Meta Tags** inventories
the package's top-level tag names and can rename a tag everywhere it occurs in the
package draft, including adding Package or All Tracks tags and deleting tags; and **Tree** is a plain folding `key : value` dictionary for the
package and its tracks, using the same dense Key/Value/Type table style. Columns are built
from scalar tags found in the package, so format-specific fields remain visible
without mixing attachments or structural objects into the audio rows. Technical
and diagnostic fields live on their own table page. Structured values are
shown as compact counts and remain closed until their scoped editor is opened;
raw JSON is an escape hatch, never the default view. “Add column” creates a
metadata field, and package-level and per-member fields stay separate. Selecting
a track keeps the audio table as the primary navigation surface. When a single
UAC is opened directly, the library rail collapses to give the track table the
full width; it returns automatically when a collection is open. UACMan restores
the last existing UAC path (or collection path) on launch when there is no
command-line document argument.
Track columns measure their longest loaded value and ease to the new widths over
200 ms. The Meta Tags example is the shared value when every use agrees, or
`Varies · N values` when it does not; structured values remain compact
`Object · N` or `List · N` entries. The app does not write native SPC bytes or
play audio.

The app reads native SPC tags from a seekable `tar+zstd-seekable` UAC wrapper.
The `UACManMetadataCLI` product reads source directories through MetaManCore for
creation-time harvest. SPC keeps its soundtrack-aware projection; VGM and VGZ
use the common member projection, including GD3 metadata such as Genesis game,
system, composer, and timing fields. Standard audio (including FLAC) and APE
preserve their ordered native tags, including unknown fields, in the UAC
metadata projection while retaining the unchanged source audio. PNG, `.cue`,
`.txt`, `.md`, and other source files are ordinary byte-exact UAC members with
BLAKE3 identities; arbitrary JSON metadata can point to them (for example
`cover_front`, `cover_back`, and `cue_sheet`). Current players preserve but do
not interpret external CUE indexes to split one FLAC member into virtual
tracks. NSF, NSFE, and GBS track-aware results can
be represented as ordered UAC `subsong` playlist entries that point to the
same original member. The member retains only shared metadata, while each entry
retains its MetaMan track projection and decoder track index. Original members
remain byte-identical; metadata saves rewrite only the manifest and preserve
the compressed payload byte-for-byte.

For GBS, the directory harvester also supplies sibling NEZplug extended-M3U
sidecars to MetaMan. Authored track names, timing, and M3U comment tags are
projected onto the matching GBS subsongs; the original M3U files remain intact
as ordinary UAC members.

Build the CLI bridge with `swift build -c release --product UACManMetadataCLI`.
Its `harvest-spc-directory <path>` command emits the specialized SPC projection.
Its `harvest-format-directory <extension> <path>` command emits member and
per-track metadata for a MetaMan-supported source format, including VGM/VGZ,
MDX, SID, NSF, NSFE, GBS, Atari ST SNDH, standard audio, and APE. It rejects `.uac`
containers; package manifests use the wrapper reader directly. Neither command
duplicates native parsing or writes source tags. Standard audio and APE members
up to 1 GiB are eligible for metadata harvest; the general source-member reader
limit remains 64 MiB. A successfully harvested member becomes a UAC playable
track by default, including MetaMan-supported formats not in UACMan's built-in
extension list; an explicit recipe role can keep a member as an asset.

NSF-family tracks use the source track index as the UAC `trackIndex` so players
can select a subsong without extracting or rewriting the stream. MetaMan
results with missing, negative, or duplicate decoder indexes fail the harvest;
they are never flattened into one member record. UAC playlist order and the
per-track projection retain the metadata used for each catalog row.

Build and launch the app bundle with:

```sh
./launch.sh
```

LaunchPad uses `./launch.sh --build-only` followed by
`open -W -n ./.build/UACMan.app` so it can track the app until it quits.
The app bundle registers `org.vgmman.uac` with Finder and supplies the
UACMan document icon for `.uac` files.

Compressed manifests currently use the installed `zstd` command-line tool;
`UACWrapperCore` owns validation and payload-preserving metadata rewrites. The
project is divided by responsibility: `Application/` contains the browser,
editor, and metadata bridge; `Wrapper/` is an independently consumable Swift
package for the current reversible format and CLI; `Container/README.md`
records the closed SPC successor decision. Native SPC conversion is not a
supported package or development path.
The current `.uac` remains a wrapper around original format members. See
[`ai/subsystem-agent/uac-editor.md`](ai/subsystem-agent/uac-editor.md),
[`ai/subsystem-agent/uac-wrapper-format.md`](ai/subsystem-agent/uac-wrapper-format.md),
[`ai/subsystem-agent/player-integration.md`](ai/subsystem-agent/player-integration.md),
and the format-specific [`protocols/PSX-CDXA.protocol.md`](protocols/PSX-CDXA.protocol.md)
for editing, format, and consumer contracts.

The Python pack/inspect/unpack CLI is `Wrapper/python/uacman.py`; its tests and
vendored BLAKE3 runtime are kept beside the wrapper.

To run the real-package integration check against a local SPC UAC:

```sh
UACMAN_REAL_SPC_PACKAGE=/path/to/spc-set.uac swift test --filter realSPCContainerCanBeHarvestedAndManifestRewrittenWithoutTouchingPayload
```
