# FrontendCore

Small, UI-neutral support shared by native frontend hosts.

`FrontendPreferencesCore` supplies the cross-app 200 ms animation defaults and
safe 0–1000 ms bounds. Each frontend retains its own renderer and persists its
own typed preference snapshot.

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

`PlaybackTransportCore` owns pure transport decisions that are shared across
frontends but do not touch audio: queued adjacent-track fade eligibility and
the bounded fade duration. VGMBoy remains responsible for the actual output
gain ramp and decoder timing.

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
