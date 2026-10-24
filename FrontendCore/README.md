# FrontendCore

`FrontendCore` contains UI-neutral services shared by CocoaSpice, SB2, ViewBoy,
and LineBoy; retired SPCBoyWK remains a historical consumer. Its modules own
archive-cache identity and policy, cache leases, preferences, favorites and
playlist identity, shared startup progress, playback queues, and native
transport coordination. The package does not read or write the catalog,
prepare playback/export archive sources, decode audio, or render a frontend.

`VGMBoyArchiveCore` owns archive/member validation, archive-tool execution,
UAC frame decoding, dependency preparation, and temporary playback/export
sources. FrontendCore's archive module adapts that engine to frontend-owned
durable cache policy for browsing and artwork; it is not the playback
extractor. CatalogReader owns read-only catalog access. VGMBoyKit owns
decoding, timing, and the audio device.

## Build and test

```sh
swift test --package-path . --disable-sandbox
```

For task routing and engineering constraints, read [AGENTS.md](AGENTS.md), then
[`ai/project-info.md`](ai/project-info.md). The focused agent notes cover archive
services and shared frontend policy.
