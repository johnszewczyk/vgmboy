# FrontendCore

`FrontendCore` contains UI-neutral services shared by CocoaSpice, SPCBoyWK, and
ViewBoy. Its modules own bounded archive materialization/cache behavior,
preferences, favorites and playlist identity, playback queues, and native
transport coordination. The package does not read or write the catalog, decode
audio, or render a frontend.

Archive listing and playback preparation receive tool execution from their
hosts; `ArchiveMaterializationCore` and `ArchiveCacheCore` own the shared
contracts, validation, lifetime, and cleanup. CatalogReader owns read-only
catalog access. VGMBoy owns decoding, timing, and the audio device.

## Build and test

```sh
swift test --package-path . --disable-sandbox
```

For task routing and engineering constraints, read [AGENTS.md](AGENTS.md), then
[`ai/project-info.md`](ai/project-info.md). The focused agent notes cover archive
services and shared frontend policy.
