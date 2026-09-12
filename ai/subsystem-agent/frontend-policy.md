# Frontend Policy

## Scope

UI-neutral identity, persistence, preferences, request, queue, and transport
contracts shared by CocoaSpice and SPCBoyWK.

## Ownership

- `LocalFileBrowserCore` owns explicit local-folder navigation values.
- `FavoriteTrackCore`, `FavoriteStoreCore`, and `PlaylistIdentityCore` own stable
  identities, group semantics, ordered shared persistence, and playlist identity.
- `FrontendPreferencesCore` owns typed option organization, shared values, and
  playlist preference validation (known columns, fixed positions, one-visible
  fallback, and explicit sortable-column requests); each frontend retains its
  key namespace, labels, width units, and rendering. It also publishes the
  shared eight-point-per-side minimum header padding; font measurement,
  indicators, and width-unit conversion remain renderer-local.
- `PlaybackRequestCore` owns newest-request-wins lifecycle and serial native
  command execution.
- `PlaybackQueueCore` owns pure queue identity, adjacent navigation, repeat
  decisions, generation-checked natural-end claims, and their typed bridge
  request/response contracts.
- `PlaybackTransportCore` owns serialized native commands, invalidation, timing
  reconfiguration, monotonic status ordering, completion retirement, and queued
  adjacent-track fade policy.

## Invariants

- Stable identity is based on catalog IDs and source/member paths, not display
  text or frontend row objects.
- `PlaybackTransportStatusPayload` is the common reply/event projection;
  `status_sequence` lets a frontend reject delayed snapshots without polling.
- `PlaybackContinuationRequest` and `PlaybackContinuationResponse` are the
  completion wire contract. Their explicit `playlistIds`, `currentTrackId`,
  and `trackId` coding prevents bridge-local aliases or lifecycle policy.
- `PlaybackQueueAdjacentRequest` and `PlaybackQueueAdjacentResponse` do the
  same for an explicit user navigation gesture. A renderer supplies IDs,
  direction, and wrapping preference; it does not compute the anchor or target.
- `PlaybackTransportStartRequest` carries a stable track ID, source/archive
  reference, timing, tempo, and seek offset into a typed host boundary. An
  adapter may materialize an archive member, but the shared transport builds
  the load/seek/play sequence and publishes the original track ID.
- `PlaybackTimingPreviewRequest`, `PlaybackTransportReconfigurationRequest`,
  and `PlaybackTransportTempoRequest` are the corresponding typed timing
  bridge contracts. They own policy-preview scaling, playback-mode payload
  construction, and normalized tempo; a frontend passes user intent and never
  rebuilds those VGMBoy values from untyped bridge dictionaries.
- `PlaybackTransportAudioConfigurationRequest` is the complete output snapshot
  for volume, EQ, and mono. `PlaybackTransportCoordinator.configureAudio(_:)`
  normalizes and serializes all three control commands; presentation adapters
  must not keep a positional audio bridge or choose their own command order.
- `PlaybackTransportAACExportRequest` and its cancellation/result contracts
  carry a finite offline render into the shared AAC exporter. A frontend adapter
  may materialize an archive member and publish UI progress, but it does not
  parse export fields or reconstruct `AACExportRequest`.
- `PlaybackTransportSeekRequest` and `PlaybackTransportRampGainRequest` name
  the direct session controls at the bridge boundary. Their shared
  normalization keeps a renderer from relying on scalar argument order.
- `PlaybackQueuedSkipFadeRequest` carries the complete queue-fade policy input
  used by both CocoaSpice and WebKit. The shared request returns the bounded
  duration in seconds or milliseconds; a renderer owns only its delayed UI
  handoff and output-ramp invocation.
- FrontendCore does not decode audio, ramp output gain, store UI models, or own
  renderer focus and selection.
- `FrontendPlaylistColumnSchema` normalizes persisted layout/sort inputs before
  they reach either renderer. AppKit points and WebKit percentage widths remain
  renderer-local because they do not have a common unit.
- `FrontendPlaylistColumnSizing` supplies the common header-only horizontal
  padding contract. It is a presentation setting carried through the WebKit
  snapshot, not a per-column rule or a second pixel-geometry implementation.
- App-specific UserDefaults keys and presentation state remain in the frontend.

## Files

- `Sources/LocalFileBrowserCore/`
- `Sources/FavoriteTrackCore/`
- `Sources/FavoriteStoreCore/`
- `Sources/PlaylistIdentityCore/`
- `Sources/FrontendPreferencesCore/`
- `Sources/PlaybackRequestCore/`
- `Sources/PlaybackQueueCore/`
- `Sources/PlaybackTransportCore/`
- corresponding directories under `Tests/`
