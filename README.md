# FrontendCore

Small, UI-neutral support shared by native frontend hosts.

`FrontendPreferencesCore` supplies the cross-app animation defaults, enable
flags, safe 0–1000 ms bounds, and the default-on column auto-size preference.
`FrontendPreferencesStore` and `FrontendPreferencesCoordinator` provide the
shared UserDefaults-backed interface state boundary; each frontend supplies
only its key namespace and renderer while using the same preference meanings.

`ArchiveMaterializationCore` turns a catalog-selected archive member into a
dependency-complete temporary or cache-backed playable file. Its format
requirement comes from VGMBoy; `ArchiveCacheMaterializer` owns shared warm-hit,
atomic staging, completion-marker, and cache-limit orchestration while the
frontend supplies only archive-tool execution. It does not read the catalog,
scan paths, decode audio, or own playback policy. `CatalogReader` remains the
read-only catalog boundary and `VGMBoy` remains the playback/decode boundary.

`ArchivePlaybackMaterializer` is the common cache-backed playback adapter used
by both CocoaSpice and SPCBoyWK. It preserves the selected-entry versus
complete-set distinction, dependency preparation, playable-member return
semantics, output validation, cache leases, and cleanup in one native path;
frontends provide only their cache root and preference-key namespace.

`ArchiveCacheCore` owns durable/disposable archive playback cache roots,
abandoned-work recovery, protected-root LRU pruning, stable archive identity,
free-space checks, policy enforcement, and cache-touch semantics. Archive
format listing, extraction tools, and frontend cache preferences remain outside
this package.

`ArchiveListingParser` owns bounded, pure 7-Zip, TAR, and RSN listing parsing,
including reversible BSD-tar octal pathname rendering. `ArchiveManifestReader`
owns temporary, non-cache manifest extraction; process execution remains a
frontend adapter.

`PlaybackRequestCore` owns UI-neutral playback request lifecycle and serial
command execution. `PlaybackRequestLifecycle` supplies newest-request-wins
generation and cancellation semantics; `PlaybackSerialExecutor` protects one
VGMBoy session from concurrent native bridge commands. It does not own a
playlist, queue policy, decoder, or renderer.

`PlaybackQueueCore` owns the shared queue identity rules extracted from
CocoaSpice: transport target resolution, adjacent-track navigation, natural
completion continuation, and replacement-queue current/selected state. It
operates on stable IDs so native CocoaSpice models and SPCBoyWK's WebKit
renderer use the same transitions without sharing UI models.

`PlaybackTransportCore` owns the shared native transport boundary: queued
adjacent-track fade eligibility and bounded fade duration, serialized commands,
request invalidation, timing reconfiguration, status snapshots, and the
one-shot generation-checked natural-end event. VGMBoy remains responsible for
the actual output gain ramp and decoder timing.

`VGMBoyKit` owns the shared `PlaybackTimingPolicy`, configurable fade policy,
tempo-aware playback plan, and offline `AACExporter`. Frontends may expose
controls and destinations, but do not decode or render audio themselves.

`ArchiveCacheCore` exposes the canonical cache choices of 2, 4, 8, and 16 GB
with a 2 GB default. Frontend option panels must consume that policy rather
than maintaining app-specific cache ranges.

The current implementation supports normal archives through `bsdtar` and
`.tar.zst`/`.tar.zstd` through `zstd` piped into `bsdtar`. The shared
`ArchiveMaterializationSession` releases the active temporary member before
the next one is materialized and when the frontend releases playback state;
`ArchiveCacheMaterializer` activates the shared cache lease for durable
materializations.

This is the seed for extracting more CocoaSpice librarian-facing behavior
without copying its database model or UI state into each skin. Archive listing,
manifest reads, executable discovery, and format-specific TAR+Zstandard piping
remain frontend adapters until their ownership is ported deliberately.
