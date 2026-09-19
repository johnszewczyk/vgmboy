# CocoaSpice

CocoaSpice is the native AppKit/SwiftUI player frontend for the VGMMan family.
It reads ScanSong’s schema-24 catalog, builds editable playlists, materializes
archive members for playback, and bundles VGMBoyKit in-process. ScanSong owns
catalog writes; VGMBoy owns decoding, timing, transport, and audio output.

## App-family boundaries

| Component | Owns |
| --- | --- |
| ScanSong | Source discovery, inspection orchestration, and catalog publication. |
| MetaMan | Decoder-independent metadata readers used by ScanSong and UACMan. |
| CatalogReader | Read-only catalog access and shared browser projections. |
| FrontendCore | Shared archive, preference, queue, and transport policy. |
| VGMBoy | Playback admission, decoding, timing, and audio output. |
| CocoaSpice | Native presentation, local UI state, and host adapters. |

SPCBoyWK and ViewBoy are separate WebKit frontends in this same family. The
legacy Electron SPCBoy is recovery material and is not an active app target.

## Build and run

```sh
./build.sh
./launch.sh
```

The launch script packages and opens `dist/CocoaSpice.app`. Choose the desired
published ScanSong catalog in Database options when the default is not correct.

For engineering rules and task routing, read [AGENTS.md](AGENTS.md), then
[`ai/project-info.md`](ai/project-info.md). Current user behavior is documented
under `ai/subsystem-human/`; engineering contracts live in
`ai/subsystem-agent/`. Decoder and dependency details are maintained in
[`../VGMBoy/README.md`](../VGMBoy/README.md). Preserve bundled upstream notices
in [`THIRD_PARTY_LICENSES.md`](THIRD_PARTY_LICENSES.md).
