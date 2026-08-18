# Timing, Long Play, and Fade

## Scope

Decode-window planning, long play, and fade for every decoder family.

## Ownership

`TimingPolicy.plan` turns a requested mode and `TrackMetadata` into a `PlaybackPlan`
(`preFadeSeconds`, `fadeSeconds`, `isLongPlay`, `usesNativeEnding`, `totalSeconds`).
`PlaybackSession.load` applies the plan: for a native ending it configures the decoder to end at its
tagged length and sets no frame cap; for a capped window it calls `configureFade` and caps the
stream at `totalSeconds * sampleRate`.

## Invariants

- Position is decoder-authoritative via `absolutePlayedFrames`; seeks and reconfiguration never
  lose the timeline.
- Long play caps the stream at (manual + fade) in the shell for every family. Native ending relies
  on the decoder's own `trackEnded` (capped only as a backstop).
- Families with `hasNaturalEnding == false` never use a native ending — always a capped window.
- The fade is applied once. Cores with native fade (`appliesFadeInternally`) do their own ramp and
  the session adds none; real-PCM cores get a linear fade-out over the final `fadeSeconds` before
  the cap from `PlaybackSession.applyFadeIfNeeded`.
- `fadeGain` is a pure function of frame position so it is unit-testable.

## Lifecycle

`fadeFrames` is computed at load from the plan and cleared on release. The cap check
(`absolutePlayedFrames >= capFrames`) and fade are evaluated on the session's serial queue during
refill and prime.

## Files

- [TimingPolicy.swift](/Users/john/Downloads/Code/VGMBoy/Sources/VGMBoyKit/TimingPolicy.swift)
- [PlaybackSession.swift](/Users/john/Downloads/Code/VGMBoy/Sources/VGMBoyKit/PlaybackSession.swift)
- [TrackMetadata.swift](/Users/john/Downloads/Code/VGMBoy/Sources/VGMBoyKit/TrackMetadata.swift)
