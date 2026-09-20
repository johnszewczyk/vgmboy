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
The workspace is organized into four pages: **Tracks** is the wide canonical
field grid for playable members, **Files** lists every stored member, **Pack Tags**
edits package-level fields and attachments, and **Track** provides an exhaustive
tag editor for a selected file. Files also offers a read-only text preview for
bundled JSON, Markdown, CUE, and other recognized text members without extracting
or rewriting the payload. Every table uses the same measured field-grid builder:
each column starts at the longest visible cell value, while headers reserve 1rem
of horizontal padding on each side. Structured values remain closed until their
Multiple Values child table is opened; the source row stays in place while the
child table expands below it. Metadata keys are case-sensitive arbitrary JSON
keys; camelCase is the shared naming convention, not a validation restriction.
When a single UAC is opened directly, the library rail collapses to give the
track table the full width; it returns automatically when a collection is open.
UACMan restores the last existing UAC path (or collection path) on launch when there is no
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
