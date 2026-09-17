# MetaMan

MetaMan is the family’s decoder-independent metadata reader. `MetaManCore`
exposes typed metadata documents to ScanSong, UACMan, and other Swift clients;
the command-line tool is a thin inspection front end.

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
