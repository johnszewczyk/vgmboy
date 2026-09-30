# Playback Transport

## Scope

- SPCBoyWK's renderer and native-bridge integration with shared playback policy.

## Ownership

- `FrontendCore.PlaybackTransportCore.PlaybackFadePolicy` owns faded-track-change
  eligibility and duration for both SPCBoyWK and CocoaSpice. Playlist activation
  and Previous/Next submit the same `PlaybackQueuedSkipFadeRequest` facts.
- SPCBoyWK owns the renderer's queued target, timer, generation checks, and
  post-fade handoff. Those steps remain separate from CocoaSpice's native
  presentation adapter.
- The native host accepts `PlaybackTransportRampGainRequest` and forwards the
  common output-gain command to VGMBoy. Keep fade eligibility and duration out
  of renderer-local arithmetic.

## Invariants

- Preserve parity by deriving the request from current playback state and using
  the shared policy result for both playlist activation and adjacent transport.
- Bind each queued target to its playback and native-session generations. A
  stale timer or completion event must not switch tracks in a newer session.
- Cancel the queued target and timer before an interrupting transport action;
  restore output gain when abandoning an active faded skip.

## Files

- [app-playback.js](../../Sources/SPCBoyWK/Resources/app-playback.js)
- [WKPlaybackBridge.swift](../../Sources/SPCBoyWK/WKPlaybackBridge.swift)
- [PlaybackFadePolicy.swift](../../../FrontendCore/Sources/PlaybackTransportCore/PlaybackFadePolicy.swift)
