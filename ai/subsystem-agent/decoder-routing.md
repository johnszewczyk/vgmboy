# Decoder Routing and Families

## Scope

Extension-based routing of files to the correct upstream decoder core, and the uniform
`AudioDecoder` contract every core satisfies.

## Ownership

`FormatRegistry` maps a path extension to a `DecoderFamily` (`id`, `supportsLongPlay`,
`supportsTempo`, `hasNaturalEnding`). `DecoderFactory.make` builds the matching decoder through the
`AudioDecoder` protocol. Extensions are deliberately exclusive to one family; `wav` is not
registered because vgmstream's Nintendo DS SWAV content sniffing is not implemented here.

## Invariants

- A file must resolve to exactly one family. Unsupported input throws
  `DecoderFactoryError.unsupportedFamily` — never an invented track.
- `hasNaturalEnding == false` (lazyusf/USF) forces a capped decode window so a looping core can
  never run indefinitely. `TimingPolicy.plan` carries this through `usesNativeEnding`.
- `appliesFadeInternally` distinguishes cores with native fade (libgme, libvgm) from real-PCM
  streamers (vgmstream, lazyusf, playpsf) that delegate the fade to `PlaybackSession`.
- Bridges are copied into VGMBoy (`Sources/C<Core>`); the upstream static libs are never re-vendored
  or built here. Symbol prefixes are per-core (`vgmboy_play_psf_*`, etc.).

## Failure Boundaries

- Bridge `create` failures surface as localized decoder errors; decode-time bridge failures return
  silence for that chunk rather than crashing the transport.

## Files

- [FormatRegistry.swift](/Users/john/Downloads/Code/VGMBoy/Sources/VGMBoyKit/FormatRegistry.swift)
- [AudioDecoder.swift](/Users/john/Downloads/Code/VGMBoy/Sources/VGMBoyKit/AudioDecoder.swift)
- [GMEDecoder.swift](/Users/john/Downloads/Code/VGMBoy/Sources/VGMBoyKit/GMEDecoder.swift)
- [VGMDecoder.swift](/Users/john/Downloads/Code/VGMBoy/Sources/VGMBoyKit/VGMDecoder.swift)
- [VgmstreamDecoder.swift](/Users/john/Downloads/Code/VGMBoy/Sources/VGMBoyKit/VgmstreamDecoder.swift)
- [LazyUSFDecoder.swift](/Users/john/Downloads/Code/VGMBoy/Sources/VGMBoyKit/LazyUSFDecoder.swift)
- [PlayPSFDecoder.swift](/Users/john/Downloads/Code/VGMBoy/Sources/VGMBoyKit/PlayPSFDecoder.swift)
