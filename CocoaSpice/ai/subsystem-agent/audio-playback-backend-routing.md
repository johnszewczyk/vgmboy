# VGMBoy Playback Integration

## Scope

- CocoaSpice's in-process connection to VGMBoyKit.

## Ownership

- VGMBoyArchiveCore owns archive/member validation and temporary source
  preparation. VGMBoyKit owns format routing, decoder bridges, audio output,
  timing, Long Play, tempo, fade, and equalizer processing.
- CocoaSpice owns playlist membership, queue navigation, repeat/shuffle policy,
  database rows, archive source identity, durable cache preferences, UI, and
  macOS transport registration. FrontendCore owns shared cache policy and
  cache-backed browsing/artwork adapters; CocoaSpice does not prepare playback
  members or access decoder implementations.
- CocoaSpice owns the remembered AAC destination and the playlist context-menu
  action; the shared intake produces a naked playable file and VGMBoy owns the
  offline AAC render.

## Invariants

- `VGMBoyKit.FormatRegistry.playbackDescriptors` is the complete frontend capability projection.
  CocoaSpice's `PlaybackFormatRegistry` is only an archive-admission adapter and must not rebuild
  extension unions, backend IDs, Long Play, tempo, or natural-ending flags.
- SAP's descriptor routes to the ASAP decoder family, which supports Long Play and
  does not support tempo. Play Speed is one frontend preference; the capability
  manifest decides which tracks receive it.
- `VGMBoyKit.PlaybackPreferences` owns timing, fade, EQ, volume, mono, and native-tempo
  normalization. `AppSessionPersistence` retains CocoaSpice's UserDefaults keys and legacy-shape
  compatibility while passing values through that shared semantic model.

- `FrontendCore.PlaybackTransportCore.PlaybackTransportCoordinator` is the
  shared native playback façade. It owns the serialized `PlaybackController`,
  newest-request token, loaded source/member identity, timing reconfiguration,
  output controls, status, diagnostics, and the generation-checked one-shot
  natural-end event.
- CocoaSpice's `VGMBoyPlaybackEngine` is only a TrackItem/archive-materializer
  adapter around that coordinator. The retired SPCBoyWK `WKPlaybackBridge` was
  a JSON request adapter around the same coordinator. Neither implementation
  owns a second controller or serial executor.
- `VGMBoyPlaybackEngine` retains its frontend `TrackItem` snapshot behind a
  lock because async playback requests and transport callbacks use different
  executors. Callback identity comes from the coordinator's queue-confined
  string ID; callbacks must not read the adapter's mutable TrackItem.
- `PlaybackRequestCore.PlaybackRequestLifecycle` owns newest-request
  invalidation for CocoaSpice's frontend playback request. Its
  `PlaybackRequestState` adapter retains only the pending `TrackItem` and
  presentation-facing end state. Queue identity and completion target policy
  live in `PlaybackQueueCore`; CocoaSpice retains only native model mapping and
  presentation state. Native transport request invalidation is shared and occurs
  before a stop or replacement can race a start.
- User-selected playlist targets, including Return activation, and adjacent
  transport targets pass through one `PlayerViewModel.requestFadedTrackChange`
  policy boundary. It uses FrontendCore's `PlaybackQueuedSkipFadeRequest`, the
  same eligibility and duration policy used by the retired SPCBoyWK frontend. CocoaSpice keeps its
  own delayed target handoff; `VGMBoyPlaybackEngine.beginFadedSkip` sends the
  ramp through the shared `PlaybackTransportCoordinator` and VGMBoy command
  path. Keep `requestPlayback` as the low-level start path for resume, playlist
  replacement, and natural completion; bypassing the policy on a
  user-selected target makes Faded Skip apply only to transport buttons.
- `PlaybackControlSurface` is read by the shared coordinator and is the
  capability gate for frontend Audio-panel mappings. Volume, Mono, EQ, timing,
  and transport commands all reach VGMBoy through that one mapping point; no
  frontend audio DSP or alternative output path exists.
- CocoaSpice passes a direct source path or the original archive path and
  selected member, plus its subtrack index, to VGMBoy. The format-owned source
  preparation requirement comes from `VGMBoyKit.FormatRegistry`; VGMBoyArchiveCore
  validates and prepares the playable source and owns its temporary session
  lifetime. FrontendCore's `ArchiveCacheCore` owns durable cache identity,
  warm-hit behavior, atomic cache staging, limit enforcement, and leases for
  browsing/artwork. CocoaSpice supplies cache preferences and
  catalog/playback presentation; its archive import and browsing paths remain
  separate from playback preparation.
- `PlaybackTransportCoordinator` builds the shared `PlaybackTimingRequest` from the selected path and
  Long Play state. Ordinary file-default timing sends no play length, so VGMBoy derives the
  natural window from decoder metadata. Long Play alone supplies the manual duration; a catalog
  duration remains a display/queue fact and is not authoritative for the core's finite playback
  cap.
- CocoaSpice does not submit a missing-length timed request. The core's bounded safety value is
  for unknown-duration/timed operations, not ordinary FLAC, WAV, or other finite audio.
- Database playlist hydration is shared CatalogReader work. CocoaSpice adapts the returned catalog
  rows into native queue models but does not retain duplicate source, folder, or path SQL.
- CocoaSpice persists separate Long Play and unknown-duration values. The latter is sent through
  the shared typed request and applies only when the decoder provides no natural duration.
- A persisted Long Play value of zero is meaningful and must survive the CocoaSpice options UI,
  control surface, timing adjustment, and UserDefaults restoration. For PSF files without a
  `_length` tag, file-default playback remains bounded by the unknown-duration preference; zero
  Long Play removes that cap while the emulated driver continues producing audio.
- AAC export passes the playlist display name and the already-effective finite playback timing to
  `PlaybackTransportCoordinator`, which calls `PlaybackController.exportAAC`.
  CocoaSpice never gives VGMBoy catalog access or asks it to derive
  a title; VGMBoy performs filename sanitation and no-overwrite collision handling. CocoaSpice shows
  native render progress in its status bar and sends Abort through the shared cancellation token;
  VGMBoy removes the unfinished partial file before it returns cancellation.
- CocoaSpice does not link its former decoder bridges or create an audio engine. Duplicate playback implementations are unsupported.
- CocoaSpice is not the owner of ScanSong's vgmstream or Highly Complete inspection plugins. Those
  executables are built and handed off by VGMBoy; CocoaSpice only provides the shared upstream
  source/build inputs used by the app family.
- Core status updates CocoaSpice display state, while the coordinator's
  one-shot natural-end event returns the shared completion target. After the
  main-actor handoff the adapter asynchronously refreshes transport status and
  orders UI delivery by status sequence. It accepts a natural end only while
  the same generation and track remain loaded and ended; if an ordinary status
  arrives first, it refreshes rather than discarding the one-shot end. CocoaSpice
  maps the stable ID into its queue model and keeps frontend-local random choice.
- VGMBoy retains one silent initialized macOS output endpoint for the host lifetime. CocoaSpice
  must express pause, replacement, seek, and completion only through the typed core controls; it
  must not stop/recreate a separate device path around those transitions.
- The CocoaSpice equalizer UI maps directly to VGMBoy's ten 31 Hz–16 kHz bands, constrained to -12...+12 dB.
- Play Speed persists one frontend preference and reconfigures a loaded tempo-capable track with both its tempo-scaled timing plan and shared `PlaybackTempo`. A tempo-only `set_tempo` command does not update the active frame cap. Decoder families without native tempo support always receive the default multiplier.
- `FormatRegistry.family(for:)` resolves a source path, not a bare extension. CocoaSpice adapts a playable extension as `source.<extension>` through one `playbackFamily(forPathExtension:)` helper for both initial tempo selection and the live `set_tempo` eligibility check.
- CocoaSpice persists its chosen App Volume and Mono preferences, then reapplies them to a newly created bundled core. VGMBoy owns the actual attenuation and real-time channel downmix.
- `build.sh` packages VGMBoy's dynamic decoder requirements under `Contents/Frameworks`; SID uses the bundled `libsidplayfp.7.dylib` via `@executable_path`, never a runtime Homebrew path or a user-chosen core executable.

## Files

- [VGMBoyPlaybackEngine.swift](../../Sources/CocoaSpice/App/VGMBoyPlaybackEngine.swift)
- [PlayerViewModel.swift](../../Sources/CocoaSpice/App/PlayerViewModel.swift)

The playback adapter does not release frontend scratch caches during transport
changes and has no in-memory UAC/SPC preparation path. Source leases and selected
SPC materialization are owned by VGMBoy; cache controls remain for browsing/art.
