# Frontend Policy

## Scope

UI-neutral identity, persistence, preferences, request, queue, and transport
contracts shared by CocoaSpice and SPCBoyWK.

## Ownership

- `LocalFileBrowserCore` owns explicit local-folder navigation values.
- `FavoriteTrackCore`, `FavoriteStoreCore`, and `PlaylistIdentityCore` own stable
  identities, group semantics, ordered shared persistence, and playlist identity.
- `FrontendPreferencesCore` owns typed option organization and validated shared
  values; each frontend retains its key namespace and rendering.
- `PlaybackRequestCore` owns newest-request-wins lifecycle and serial native
  command execution.
- `PlaybackQueueCore` owns pure queue identity, adjacent navigation, repeat
  decisions, and generation-checked natural-end claims.
- `PlaybackTransportCore` owns serialized native commands, invalidation, timing
  reconfiguration, monotonic status ordering, completion retirement, and queued
  adjacent-track fade policy.

## Invariants

- Stable identity is based on catalog IDs and source/member paths, not display
  text or frontend row objects.
- `PlaybackTransportStatusPayload` is the common reply/event projection;
  `status_sequence` lets a frontend reject delayed snapshots without polling.
- FrontendCore does not decode audio, ramp output gain, store UI models, or own
  renderer focus and selection.
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

