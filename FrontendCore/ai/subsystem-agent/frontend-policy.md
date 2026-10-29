# Frontend Policy

## Scope

UI-neutral identity, persistence, preferences, request, queue, transport, and
startup contracts shared by the VGMMan player frontends.

## Ownership

- `LocalFileBrowserCore` owns explicit local-folder navigation values.
- `FavoriteTrackCore`, `FavoriteStoreCore`, `PlaybackHistoryCore`, and
  `PlaylistIdentityCore` own stable identities, group semantics, shared
  persistence, and playlist identity. PlaybackHistoryCore stores successful
  play events as timestamped JSON records shared by the native player hosts.
- `FrontendPreferencesCore` owns typed option organization, shared values, and
  playlist preference validation (known columns, fixed positions, one-visible
  fallback, and explicit sortable-column requests); each frontend retains its
  key namespace, labels, width units, and rendering. It also publishes the
  shared eight-point-per-side minimum header padding; font measurement,
  indicators, and width-unit conversion remain renderer-local.
- `PlaylistTabsPersistenceCore` owns the ordinary ordered-ID transitions for
  playlist-tab insert, activate, close fallback, move, and restore. Frontends
  retain tab payloads, snapshot storage, visual behavior, and final-tab policy.
- `PlaybackRequestCore` owns newest-request-wins lifecycle and serial native
  command execution.
- `PlaybackQueueCore` owns pure queue identity, adjacent navigation, repeat
  decisions, generation-checked natural-end claims, and their typed bridge
  request/response contracts.
- `PlaybackTransportCore` owns serialized native commands, invalidation, timing
  reconfiguration, monotonic status ordering, completion retirement, and the
  shared faded-track-change eligibility and duration policy.
- A successful low-level mode change can reload the native session. The
  coordinator adopts its returned generation and resets completion claims;
  stale natural-end events are discarded before status or end delivery.
- A replacement-request stop is serialized with its newest-request check, so
  an older request cannot retire playback owned by a newer request.
- Start requests recheck ownership inside the shared load boundary after source
  preparation and before replacing the native session, then after load, seek,
  and playback start. A superseded preparation preserves the previous session;
  after native replacement begins, cancellation retires its own replacement
  before a newer queued request can begin.
- Queued status for a retired generation is not published as the current track.
  Snapshot reads are non-emitting so a callback may safely refresh the current
  state without recursively producing another status event.
  Failed starts and reconfigurations retain the previous track only if the
  native generation did not change; once replacement starts, failure clears
  coordinator track identity and retires the native session.
- `FrontendStartupCore` owns the shared four-stage startup sequence, progress
  state transitions, and reveal/ready timing policy. Frontends own startup
  rendering and app-specific loading operations.

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
- `PlaybackTransportStartRequest` carries a stable track ID, original
  source/archive reference, selected member, timing, tempo, and seek offset
  into a typed host boundary. The coordinator preserves that identity and
  sends it to VGMBoy; VGMBoyArchiveCore prepares the source before decoding.
  The shared transport builds the load/seek/play sequence and publishes the
  original track ID.
- `PlaybackTimingPreviewRequest`, `PlaybackTransportReconfigurationRequest`,
  and `PlaybackTransportTempoRequest` are the corresponding typed timing
  bridge contracts. They own policy-preview scaling, playback-mode payload
  construction, and normalized tempo; a frontend passes user intent and never
  rebuilds those VGMBoy values from untyped bridge dictionaries. A direct tempo
  request retains the active timing settings and reloads when its effective
  rate changes. Frontends that scale a track's playback window by tempo must
  refresh the timing preview and reconfigure with both the new plan and tempo.
- SB2 and ViewBoy submit `PlaybackTransportReconfigurationRequest` to the
  coordinator as one serialized operation; CocoaSpice's native timing-plan
  route uses the same coordinator operation. It gates tempo by decoder family
  and reloads with timing and tempo together, retaining track and source identity.
- A reconfiguration request can carry an expected native generation and a
  monotonically increasing settings revision. The coordinator accepts earlier
  generations from the same loaded track's reload lineage, rejects generations
  from a replaced track and discards older revisions before changing playback.
  Omitting both values retains the existing bridge contract. A newly loaded
  track resets the lineage and accepted revision; the transport's separate
  revision reservation counter remains monotonic for its lifetime.
- Renderer output-gain ramps may carry an expected native generation. The
  shared coordinator checks it on the transport queue before touching output,
  rejecting a ramp for a retired or replaced session; requests without the
  field retain their legacy behavior.
- Conditional stop has asynchronous and synchronous entry points; both check
  the latest reserved playback request on the transport queue before retirement.
- Session-scoped pause, resume and seek commands optionally carry the expected
  native generation, checked before the shared controller executes them.
  Ordered seeks can also carry a transport-reserved monotonic revision, so a
  late worker cannot overwrite a newer seek. Legacy unnumbered seeks remain valid.
- Whole-second timing plans are range-checked before conversion to native
  milliseconds for start, reconfiguration and AAC export; invalid plans fail
  before replacing the current session.
- Timing previews use the decoder family's effective rate rather than the
  stored requested preference. Native status and preview calculations must
  agree when a backend clamps or rounds a requested rate. Preview durations
  are already output-time values; consumers must not apply tempo scaling again.
  The preview also carries millisecond-precision pre-fade, fade and total
  values. Its original whole-second fields and decoding of older replies are
  retained for compatibility; new consumers should use the precise fields.
  Timing preview validates decoded durations against the native timing range
  before tempo scaling, including requests that bypass the Swift initializer.
- `PlaybackTransportAudioConfigurationRequest` is the complete output snapshot
  for volume, EQ, and mono. `PlaybackTransportCoordinator.configureAudio(_:)`
  normalizes and serializes all three control commands; presentation adapters
  must not keep a positional audio bridge or choose their own command order.
- `PlaybackTransportAACExportRequest` and its cancellation/result contracts
  carry a finite offline render into the shared AAC exporter. The request keeps
  the original archive/member identity; VGMBoy prepares it. A frontend adapter
  may publish UI progress, but it does not extract the source, parse export
  fields, or reconstruct `AACExportRequest`.
- `PlaybackTransportSeekRequest` and `PlaybackTransportRampGainRequest` name
  the direct session controls at the bridge boundary. Their shared
  normalization keeps a renderer from relying on scalar argument order. The
  async seconds-based seek checks finiteness and native range before conversion;
  finite negative values retain its existing clamp-to-zero behavior.
- `PlaybackQueuedSkipFadeRequest` carries the complete faded-track-change
  policy input used by CocoaSpice and SB2 for playlist activation
  and Previous/Next. The shared request returns the bounded duration in seconds
  or milliseconds. Each renderer owns its delayed target handoff and
  cancellation; both reach the same VGMBoy output-gain ramp command.
- FrontendCore does not decode audio, ramp output gain, store UI models, or own
  renderer focus and selection.
- `FrontendPlaylistColumnSchema` normalizes persisted layout/sort inputs before
  they reach either renderer. AppKit points and WebKit percentage widths remain
  renderer-local because they do not have a common unit.
- `FrontendPlaylistColumnSizing` supplies the common header-only horizontal
  padding contract. It is a presentation setting carried through the WebKit
  snapshot, not a per-column rule or a second pixel-geometry implementation.
- App-specific UserDefaults keys and presentation state remain in the frontend.
- Startup progress is value-only UI state. The shared package does not start
  catalog reads, restore app sessions, or decide frontend-specific errors.
- History entries use event IDs rather than song IDs so repeated plays remain
  distinct rows. Persist absolute Unix milliseconds and source/member identity;
  display formatting and queue selection remain frontend concerns.

## Files

- `Sources/LocalFileBrowserCore/`
- `Sources/FavoriteTrackCore/`
- `Sources/FavoriteStoreCore/`
- `Sources/PlaybackHistoryCore/`
- `Sources/PlaylistIdentityCore/`
- `Sources/PlaylistTabsPersistenceCore/`
- `Sources/FrontendPreferencesCore/`
- `Sources/PlaybackRequestCore/`
- `Sources/PlaybackQueueCore/`
- `Sources/PlaybackTransportCore/`
- `Sources/FrontendStartupCore/`
- corresponding directories under `Tests/`

Playback/export bridge requests preserve the original source/member identity.
There is no resolved-cache-path override or deprecated AAC-export overload;
VGMBoy owns preparation. Artwork and browse caches remain independent.
