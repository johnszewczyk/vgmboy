# UACMan

UACMan is a native macOS browser/editor for `.uac` packages. It separates
soundtrack/game-level metadata from each track's metadata, reads SPC ID666/xID6
tags through MetaMan, retains ordered duplicate tags and raw-block sizes in the
manifest while the unchanged SPC member retains the original block bytes, and
supports per-field editing plus scoped batch edits across selected tracks.
Import fills missing fields by default; replacing imported values is an
explicit action. The app does not write native SPC bytes or play audio.

The native-tag reader currently requires a seekable `tar+zstd-seekable` UAC
payload. Metadata saves rewrite only the manifest and preserve the compressed
payload byte-for-byte.

Build and launch the app bundle with:

```sh
./launch.sh
```

LaunchPad uses `./launch.sh --build-only` followed by
`open -W -n ./.build/UACMan.app` so it can track the app until it quits.

Compressed manifests currently use the installed `zstd` command-line tool;
FrontendCore receives a bounded codec adapter and owns validation and
payload-preserving metadata rewrites. See
[`ai/subsystem-agent/uac-editor.md`](ai/subsystem-agent/uac-editor.md) for
the mutation boundary.

To run the real-package integration check against a local SPC UAC:

```sh
UACMAN_REAL_SPC_PACKAGE=/path/to/spc-set.uac swift test --filter realSPCContainerCanBeHarvestedAndManifestRewrittenWithoutTouchingPayload
```
