# SPCBoyWK Agent Handoff

## Current status — shared timing and transport status

Date: 2026-08-28

SPCBoyWK no longer maintains a separate JavaScript Long Play timing policy for
the active track. The WebKit frontend asks the native bridge for a timing plan,
and the native bridge resolves it through the shared VGMBoyKit policy used by
CocoaSpice.

The shared plan covers:

- decoder Long Play capability;
- natural catalog duration;
- Long Play target duration;
- fade duration;
- unknown-duration fallback; and
- native tempo scaling.

The same returned plan drives the displayed transport duration and the native
`nativePlaybackStart` request. With the default settings, Long Play on a
loop-capable SPC resolves to 3:00 plus the 0:06 fade, or 3:06. The 2:36 value
remains the intended 2:30 unknown-duration fallback plus fade when Long Play is
off and no natural duration exists.

SPCBoyWK now consumes the shared `PlaybackTransportStatusPayload` projection
from FrontendCore for synchronous status replies and pushed playback events.
The native transport owns status publication and natural-end retirement; the
WebKit layer renders the payload and retains only its UI-generation ordering
guards.

## Files changed for this handoff

- `Sources/SPCBoyWK/WKNativeBridge.swift` exposes `nativePlaybackTiming` and
  projects native status through the shared transport payload.
- `Sources/SPCBoyWK/WKPlaybackBridge.swift` resolves the request through
  `PlaybackTimingPolicy` and returns the effective plan/status projection.
- `Sources/SPCBoyWK/Resources/app-playback.js` caches the native plan for the
  active track and uses it for display and start requests. Playback generation
  is reserved before the asynchronous timing lookup so a newer selection can
  supersede an older one.
- `FrontendCore/Sources/PlaybackTransportCore/PlaybackTransportStatusPayload.swift`
  defines the shared bridge projection.
- `Tests/SPCBoyWKTransport.test.js` covers stale native generations, queued-fade
  restoration, and the Long Play 3:06 request.
- `ai/subsystem-agent/webkit-host.md` and
  `ai/subsystem-human/playback.md` record the resulting ownership and behavior.

## Verification

- `node --check Sources/SPCBoyWK/Resources/app-playback.js`
- `node --test Tests/SPCBoyWKTransport.test.js` — 18 tests passed
- `swift build -c release` — passed with task-local Swift module/cache paths

The focused FrontendCore transport suite passed 7/7. A full FrontendCore test
run built successfully but did not produce runner output and was stopped; treat
that as an environment/runner limitation rather than source validation.

The worktree already contained substantial unrelated SPCBoyWK changes before
this handoff. Do not reset or discard them. CocoaSpice was used as the working
reference and was not modified for this change.

## Remaining live gate

Use `./launch.sh` with a real `.spc`, then verify the elapsed clock, pause/resume,
seek, natural completion, and Long Play behavior at the packaged-app boundary.
Turning Long Play off must restore the decoder-natural duration or the configured
unknown-length fallback. A fresh packaged Cyberbots check showed the clock
advancing; no source clock rewrite was made based on the earlier stale-build
report. Production SPC evidence is still required before declaring parity
complete.
