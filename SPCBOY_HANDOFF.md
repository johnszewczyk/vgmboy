# SPCBoyWK Agent Handoff

## Long Play timing unification

Date: 2026-08-25

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

## Files changed for this handoff

- `Sources/SPCBoyWK/WKNativeBridge.swift` exposes `nativePlaybackTiming`.
- `Sources/SPCBoyWK/WKPlaybackBridge.swift` resolves the request through
  `PlaybackTimingPolicy` and returns the effective plan.
- `Sources/SPCBoyWK/Resources/app-playback.js` caches the native plan for the
  active track and uses it for display and start requests. Playback generation
  is reserved before the asynchronous timing lookup so a newer selection can
  supersede an older one.
- `Tests/SPCBoyWKTransport.test.js` covers stale native generations, queued-fade
  restoration, and the Long Play 3:06 request.
- `ai/subsystem-agent/webkit-host.md` and
  `ai/subsystem-human/playback.md` record the resulting ownership and behavior.

## Verification

- `node --check Sources/SPCBoyWK/Resources/app-playback.js`
- `node --test Tests/SPCBoyWKTransport.test.js` — 3 tests passed
- `CLANG_MODULE_CACHE_PATH=/tmp/spcboywk-clang-cache swift build --configuration debug`
- `./launch.sh` — clean production build completed and the app was opened

The worktree already contained substantial unrelated SPCBoyWK changes before
this handoff. Do not reset or discard them. CocoaSpice was used as the working
reference and was not modified for this change.

## Next agent check

Manually open a real `.spc` in the production app, enable Long Play, and verify
that the transport readout changes to 3:06 by default and that playback remains
active beyond the old 2:36 fallback boundary. Also verify that turning Long
Play off restores the decoder-natural duration or the configured unknown-length
fallback.
