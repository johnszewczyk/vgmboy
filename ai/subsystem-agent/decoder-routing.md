# Decoder Routing and Families

## Scope

Extension-based routing of files to the correct upstream decoder core, and the uniform
`AudioDecoder` contract every core satisfies.

## Ownership

`FormatRegistry` maps a path extension to a `DecoderFamily` (`id`, `supportsLongPlay`,
`supportsTempo`, `hasNaturalEnding`). `DecoderFactory.make` builds the matching decoder through the
internal `AudioDecoder` protocol. Decoder headers are read only inside a live playback session for
subtrack validation and timing; the core does not expose inspection or catalog metadata. Extensions
are deliberately exclusive to one family.

## Invariants

- A file must resolve to exactly one family. Unsupported input throws
  `DecoderFactoryError.unsupportedFamily` — never an invented track.
- `hasNaturalEnding == false` (lazyusf/USF and sidplayfp/SID) forces a capped decode window so a looping core can
  never run indefinitely. `TimingPolicy.plan` carries this through `usesNativeEnding`.
- `appliesFadeInternally` distinguishes cores with native fade (libgme, libvgm) from PCM
  streamers (Highly Complete, vgmstream, lazyusf, playpsf, OpenMPT) that delegate the fade to
  `PlaybackSession`.
- Highly Complete bridge calls are serialized through one gate. Its native GBA rate may change
  while mGBA runs, so the bridge resamples to VGMBoy's requested output rate and reports output-frame position.
- 2SF bridge calls are serialized because the DS core is process-global. `PlaybackSession` calls
  `close()` before constructing a replacement decoder, so teardown never depends on ARC timing.
- Bridges are copied into VGMBoy (`Sources/C<Core>`); the upstream static libs are never re-vendored
  or built here. Symbol prefixes are per-core (`vgmboy_play_psf_*`, etc.).

## Failure Boundaries

- Bridge `create` failures surface as localized decoder errors; decode-time bridge failures return
  silence for that chunk rather than crashing the transport.

## Files

- [FormatRegistry.swift](/Users/john/Downloads/Code/VGMBoy/Sources/VGMBoyKit/FormatRegistry.swift)
- [AudioDecoder.swift](/Users/john/Downloads/Code/VGMBoy/Sources/VGMBoyKit/AudioDecoder.swift)
- [GMEDecoder.swift](/Users/john/Downloads/Code/VGMBoy/Sources/VGMBoyKit/GMEDecoder.swift)
- [SIDDecoder.swift](/Users/john/Downloads/Code/VGMBoy/Sources/VGMBoyKit/SIDDecoder.swift)
- [OpenMPTDecoder.swift](/Users/john/Downloads/Code/VGMBoy/Sources/VGMBoyKit/OpenMPTDecoder.swift)
- [VGMDecoder.swift](/Users/john/Downloads/Code/VGMBoy/Sources/VGMBoyKit/VGMDecoder.swift)
- [HighlyCompleteDecoder.swift](/Users/john/Downloads/Code/VGMBoy/Sources/VGMBoyKit/HighlyCompleteDecoder.swift)
- [TwoSFDecoder.swift](/Users/john/Downloads/Code/VGMBoy/Sources/VGMBoyKit/TwoSFDecoder.swift)
- [VgmstreamDecoder.swift](/Users/john/Downloads/Code/VGMBoy/Sources/VGMBoyKit/VgmstreamDecoder.swift)
- [LazyUSFDecoder.swift](/Users/john/Downloads/Code/VGMBoy/Sources/VGMBoyKit/LazyUSFDecoder.swift)
- [PlayPSFDecoder.swift](/Users/john/Downloads/Code/VGMBoy/Sources/VGMBoyKit/PlayPSFDecoder.swift)
