# MetaMan

MetaMan is the family’s decoder-independent metadata reader. `MetaManCore`
exposes typed metadata documents to ScanSong, UACMan, and other Swift clients;
the command-line tool is a thin inspection front end.

`MetaManCore` does not link VGMMan emulator/playback plugin libraries and
never launches subprocesses. SwiftPM has one local package dependency,
`UACWrapperCore`; the core also uses system zlib, and its standard-audio
reader uses Apple's AVFoundation. Compressed UAC manifests use a bounded
decoder callback supplied by the host. The `metaman` command-line client
currently supplies that callback through the external `zstd` executable.
Format coverage is explicit: the package reads the formats listed by
`MetaManCore.supportedFormats` and in the format map, not every format known
to VGMBoy or ScanSong.

The canonical format map documents complete-reader scope, byte layouts,
bounds, retained source facts, and validation method in
[`FORMAT-LAYOUTS.md`](FORMAT-LAYOUTS.md). It is the authority for format-level
coverage; do not duplicate its table here.

## Build and test

```sh
swift test --package-path . --disable-sandbox
```

For engineering rules and task routing, read [AGENTS.md](AGENTS.md), then
[`ai/project-info.md`](ai/project-info.md). ScanSong’s adapter boundary is
documented in [`../ScanSong/ai/subsystem-agent/format-accommodations.md`](../ScanSong/ai/subsystem-agent/format-accommodations.md).
