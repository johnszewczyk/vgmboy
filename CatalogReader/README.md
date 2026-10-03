# CatalogReader

`CatalogReader` is the shared read-only SQLite boundary for catalog-backed
player frontends. It provides canonical schema-24/25 records, browser projections,
playlist presentation values, read sessions, and frontend command contracts.
ScanSong remains the only catalog writer.

The package contains no player UI, archive extraction, decoder, or write path.
Native frontends render its snapshots.

## Build and test

```sh
swift test --package-path . --disable-sandbox
```

For ownership and task routing, read [AGENTS.md](AGENTS.md), then
[`ai/project-info.md`](ai/project-info.md). The focused agent notes are linked
there.
