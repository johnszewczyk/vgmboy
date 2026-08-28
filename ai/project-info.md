# FrontendCore project information

## Boundary

FrontendCore contains reusable, UI-neutral services needed by native frontend
hosts. It must not become a second catalog writer or playback engine.

## Current ownership

- `CatalogReader`: read-only schema-23 catalog access and archive identity.
- `ArchiveMaterializationCore`: requirement-aware selected-entry or complete-set
  extraction, PSF dependency closure, lazyUSF/TXTP preparation, cleanup, and
  cache-backed atomic materialization orchestration. Its temporary-session
  ownership and cache-lease activation are shared; archive tools remain
  injected frontend operations.
- `ArchiveListingParser`: bounded, pure 7-Zip/TAR/RSN listing parsing and
  reversible BSD-tar pathname rendering.
- `ArchiveManifestReader`: temporary, non-cache archive-manifest reads with
  frontend-supplied extraction.
- `ArchiveCacheCore`: archive playback cache roots, stable source identity,
  recovery, free-space checks, policy enforcement, cache touching, and bounded
  LRU lifecycle. CocoaSpice retains only its app error adapter and maintenance
  scheduling; cache lifecycle policy itself is shared.
- `FavoriteTrackCore`: stable cross-app track identity and group-toggle semantics.
- `FavoriteStoreCore`: versioned cross-process SQLite persistence at
  `Application Support/VGMMan/UserData.sqlite`, including ordered snapshots,
  serialized mutations, and idempotent legacy imports.
- `FrontendPreferencesCore`: shared typed Options organization, explicit window
  roles, and validated animation/window preference values used by the native
  and WebKit hosts.
- `PlaybackRequestCore`: newest-request-wins lifecycle plus the serial command
  executor shared by native playback hosts. It protects one VGMBoy session but
  does not own queue policy, catalog state, or presentation.
- `PlaybackQueueCore`: pure queue identity and continuation policy plus the
  generation-checked one-shot natural-end handoff. It stores no track models,
  decoder state, or presentation data.
- `PlaybackTransportCore`: serialized native transport commands, request
  invalidation, timing/reconfiguration, status snapshots, completion retirement,
  and queued adjacent-track fade policy. It does not perform decoder work;
  VGMBoy owns decoding and the output-gain ramp. `PlaybackTransportStatusPayload`
  is the common bridge projection for synchronous replies and pushed events.
- `VGMBoy`: decoder, timing, transport, and audio output.
- Frontends: queue, presentation, options state, and user-facing policy.

## Next extraction candidates

Remaining extraction work is adoption and contract cleanup: move any still-
duplicated queue continuation or catalog-snapshot handoff into the existing
typed boundaries only after CocoaSpice behavior is characterized. Keep shared
behavior in Swift and expose it to WebKit through typed host requests; do not
copy `PlayerViewModel`, SwiftUI state, or Electron-era JavaScript application
state into this package.
