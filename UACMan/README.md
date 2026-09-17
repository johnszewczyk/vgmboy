# UACMan

UACMan is a native macOS browser/editor for `.uac` packages. It separates
soundtrack/game-level metadata from each track's metadata, reads SPC ID666/xID6
tags through MetaMan, retains ordered duplicate tags and raw-block sizes in the
manifest while the unchanged SPC member retains the original block bytes, and
supports per-field editing plus scoped batch edits across selected playable
members.
Import fills missing fields by default; replacing imported values is an
explicit action. The app does not write native SPC bytes or play audio.

The app reads native SPC tags from a seekable `tar+zstd-seekable` UAC wrapper.
The `UACManMetadataCLI` product reads source directories through MetaManCore for
creation-time harvest. SPC keeps its soundtrack-aware projection; VGM and VGZ
use the common member projection, including GD3 metadata such as Genesis game,
system, composer, and timing fields. Track-aware results are not flattened into
member metadata. Original members remain byte-identical; metadata saves rewrite
only the manifest and preserve the compressed payload byte-for-byte.

Build the CLI bridge with `swift build -c release --product UACManMetadataCLI`.
Its `harvest-spc-directory <path>` command emits the specialized SPC projection.
Its `harvest-format-directory <extension> <path>` command emits common metadata
for a MetaMan-supported single-track source format, including VGM/VGZ and SID.
It rejects `.uac` containers; package manifests use the wrapper reader directly.
Neither command duplicates native parsing or writes source tags.

VGM/VGZ fits UAC's current single-member model: each file maps to one playable
member, while its logged chip commands and GD3 system field identify the
hardware used. NSF is also readable by MetaMan, but its files declare multiple
logical songs; the current single-track directory harvester rejects those
results instead of flattening them into one member record. A future source
import path would need to map each MetaMan result into member/playlist data.

Build and launch the app bundle with:

```sh
./launch.sh
```

LaunchPad uses `./launch.sh --build-only` followed by
`open -W -n ./.build/UACMan.app` so it can track the app until it quits.

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
and [`ai/subsystem-agent/player-integration.md`](ai/subsystem-agent/player-integration.md)
for editing, format, and consumer contracts.

The Python pack/inspect/unpack CLI is `Wrapper/python/uacman.py`; its tests and
vendored BLAKE3 runtime are kept beside the wrapper.

To run the real-package integration check against a local SPC UAC:

```sh
UACMAN_REAL_SPC_PACKAGE=/path/to/spc-set.uac swift test --filter realSPCContainerCanBeHarvestedAndManifestRewrittenWithoutTouchingPayload
```
