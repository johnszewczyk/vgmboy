# Audio Output Transport

## Scope

The VGMBoy-owned device output, PCM handoff, transport envelope, and output-health counters.

## Ownership

`PlaybackSession` is the sole PCM producer. `VGMBoyCAudioUnit` owns the single persistent
DefaultOutput AudioUnit and its render callback is the sole PCM consumer. The callback owns the
audible transport ramp at the device boundary. `AudioOutput` controls that unit; no frontend
opens or manipulates an audio device.

## Invariants

- The PCM ring is single-producer/single-consumer with atomic monotonic indices; the AudioUnit
  callback never waits for a mutex, decoder, EQ mutation, allocation, or frontend work.
- A clear advances the consumer index to the producer index. An in-flight callback must win a
  compare-and-exchange before advancing the index, otherwise it emits silence and cannot revive
  pre-seek or pre-replacement PCM.
- Start resets the device-bound gain to silence and ramps to unity over 10 ms. Pause, stop, seek,
  replacement, and natural completion ramp to silence over the same envelope. The initialized
  device endpoint remains silently running for the host lifetime; transition code must not stop
  and restart it per track because that hardware boundary can itself click.
  This is not Long Play or a musical fade.
- Session teardown stops decoder production, then preserves already queued PCM until the output
  envelope reaches silence. It must never clear that ring before the envelope: doing so is a hard
  discontinuity at exactly the transition the envelope exists to protect.
- The final callback multiplies post-EQ, post-volume PCM by the 10 ms envelope immediately before
  the default output device. `AudioOutput` gives that callback a 12 ms window before marking the
  transport paused, while retaining a silent initialized unit for seamless next-track playback.
- EQ, app volume, and mono are producer-side DSP protected from concurrent control changes; they
  remain distinct from the callback-only transport envelope.
- A frontend may request a bounded transport-gain ramp for an intentional musical transition such
  as SPCBoy's queued skip. The request changes only the core-owned final output gain; it does not
  create a second frontend audio graph or modify the user's volume/EQ setting.
- Diagnostics contain output facts only and never choose a queue transition.

## Files

- [AudioOutput.swift](/Users/john/Downloads/Code/VGMBoy/Sources/VGMBoyKit/AudioOutput.swift)
- [vgmboy_audio_unit.c](/Users/john/Downloads/Code/VGMBoy/Sources/CAudioUnit/vgmboy_audio_unit.c)
- [vgmboy_audio_unit.h](/Users/john/Downloads/Code/VGMBoy/Sources/CAudioUnit/include/vgmboy_audio_unit.h)
- [PlaybackSession.swift](/Users/john/Downloads/Code/VGMBoy/Sources/VGMBoyKit/PlaybackSession.swift)
