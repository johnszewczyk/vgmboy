# Timing, Long Play, and Fade

## Scope

Decode-window planning, long play, and fade for every decoder family.

## Ownership

`PlaybackTimingRequest` is the shared frontend boundary for timing requests. Its standard
request is decoder-natural (`file_default` with no play length) for finite files; Long Play is
the only standard mode that supplies a manual play length. An explicit `timed` request is
reserved for a caller that has an actual finite duration, such as a deliberate faded skip.
Frontends must not manufacture a timed request with a missing duration.

`TimingPolicy.plan` turns a requested mode and `TrackMetadata` into a `PlaybackPlan`
(`preFadeSeconds`, `fadeSeconds`, `isLongPlay`, `usesNativeEnding`, `totalSeconds`).
`PlaybackSession.load` applies the plan: for a native ending it uses decoder-native ending only
when the decoder also owns its fade. Libvgm exposes natural timing but its bridge does not start
an internal fade at an ordinary file end, so it uses the same session-boundary fade as Highly
Complete/mGBA. Capped windows call `configureFade` and cap the stream at `totalSeconds * sampleRate`.
The controller also forces any nonzero requested fade through this bounded path, including when
the public mode is `file_default`; this prevents a client from accidentally bypassing fade by
combining a native-ending mode with an explicit fade value.

## Invariants

- Position is decoder-authoritative via `absolutePlayedFrames`; seeks and reconfiguration never
  lose the timeline.
- Long play caps the stream at (manual + fade) in the shell for every family. Native ending relies
  on the decoder's own `trackEnded` (capped only as a backstop).
- `file_default` uses a native ending only when the requested fade is zero. A nonzero fade is an
  explicit bounded request and is applied exactly once by the decoder or shared session DSP.
- The 150-second value is only the core safety window for a timed request that lacks a natural
  duration. It is not a default duration for finite standard audio and must not be sent by a
  frontend for FLAC, WAV, or other decoder-natural formats.
- When a file's decoder reports a positive `naturalPlayMs`, that value wins over the safety
  window. Standard audio and FFmpeg audio (including APE) obtain this from the file reader; libgme, libvgm,
  Highly Complete, 2SF, vgmstream, Play!, QSF, and OpenMPT obtain it from their decoder
  metadata. SID reports no natural timing, so standard SID playback uses the safety window; a
  metadata-less lazyUSF track is handled the same way because its family has no natural ending.
- The shared request carries a user-configurable unknown-duration window. Its default is 150
  seconds; frontend Long Play duration preferences remain separate. With the default six-second
  fade, an unknown-duration track using the default is capped at 156 seconds total; with fade
  disabled it is capped at 150.
- Families with `hasNaturalEnding == false` never use a native ending — always a capped window.
- The fade is applied once. Cores that truly own native fade (`appliesFadeInternally`) do their
  own ramp and the session adds none; libvgm and real-PCM cores get a linear fade-out over the
  final `fadeSeconds` before the cap from `PlaybackSession.applyFadeIfNeeded`.
- `fadeGain` is a pure function of frame position so it is unit-testable.

## Lifecycle

`fadeFrames` is computed at load from the plan and cleared on release. The cap check
(`absolutePlayedFrames >= capFrames`) and fade are evaluated on the session's serial queue during
refill and prime.

## Files

- [TimingPolicy.swift](../../Sources/VGMBoyKit/TimingPolicy.swift)
- [PlaybackTimingRequest.swift](../../Sources/VGMBoyKit/PlaybackTimingRequest.swift)
- [PlaybackSession.swift](../../Sources/VGMBoyKit/PlaybackSession.swift)
- [TrackMetadata.swift](../../Sources/VGMBoyKit/TrackMetadata.swift)
