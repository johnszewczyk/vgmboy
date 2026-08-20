# Audio Output Transport

## Scope

The VGMBoy-owned device output, PCM handoff, transport envelope, and output-health counters.

## Ownership

`PlaybackSession` is the sole PCM producer. `AVAudioSourceNode` is the sole PCM consumer and
owns the active transport-envelope gain. `AudioOutput` owns the AVAudioEngine graph and waits for
the output boundary to reach silence before pausing it.

## Invariants

- The PCM ring is single-producer/single-consumer with atomic monotonic indices; the audio callback
  never waits for an `NSLock`, decoder, EQ mutation, or frontend work.
- A clear advances the consumer index to the producer index. An in-flight callback must win a
  compare-and-exchange before advancing the index, otherwise it emits silence and cannot revive
  pre-seek or pre-replacement PCM.
- Start resets the device-bound gain to silence and ramps to unity over 10 ms. Pause, stop, seek,
  replacement, and natural completion ramp to silence over the same envelope before pausing.
  This is not Long Play or a musical fade.
- EQ remains in the engine graph and app volume remains distinct from the transport envelope.
- Diagnostics contain output facts only and never choose a queue transition.

## Files

- [AudioOutput.swift](/Users/john/Downloads/Code/VGMBoy/Sources/VGMBoyKit/AudioOutput.swift)
- [PCMRingBuffer.swift](/Users/john/Downloads/Code/VGMBoy/Sources/VGMBoyKit/PCMRingBuffer.swift)
- [TransportEnvelope.swift](/Users/john/Downloads/Code/VGMBoy/Sources/VGMBoyKit/TransportEnvelope.swift)
- [PlaybackSession.swift](/Users/john/Downloads/Code/VGMBoy/Sources/VGMBoyKit/PlaybackSession.swift)
