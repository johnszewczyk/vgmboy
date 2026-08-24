# FrontendCore

Small, UI-neutral support shared by native frontend hosts.

`ArchiveMaterializationCore` turns a catalog-selected archive member into a
temporary playable file. It does not read the catalog, scan paths, decode
audio, or own playback policy. `CatalogReader` remains the read-only catalog
boundary and `VGMBoy` remains the playback/decode boundary.

`ArchiveCacheCore` owns only durable/disposable archive playback cache roots,
abandoned-work recovery, and protected-root LRU pruning. Archive format
listing, extraction tools, and frontend cache preferences remain outside this
package.

The current implementation supports normal archives through `bsdtar` and
`.tar.zst`/`.tar.zstd` through `zstd` piped into `bsdtar`. The active temporary
member is released before the next one is materialized and when the frontend
releases playback state.

This is the seed for extracting more CocoaSpice librarian-facing behavior
without copying its database model or UI state into each skin. Scan-time
full-archive extraction remains app-specific until its ownership and policy are
ported deliberately.
