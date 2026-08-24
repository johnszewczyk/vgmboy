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
- GameCube admission is fixture-backed and limited to primary playable DSP,
  ADP, AGSC, H4M, LDAT, LOGG, RSF, THP, and TXTP files. TXTH and bank files
  remain adjacent dependencies rather than duplicate standalone playlist rows.
- `VGMBoyFormatCore.VGMStreamFormatManifest` is the decoder-owned, database-free
  source of truth for vgmstream playback and ScanSong admission roles. Manifest
  membership never replaces native open, enumeration, timing, and fixture proof.
- `hasNaturalEnding == false` (lazyusf/USF and sidplayfp/SID) forces a capped decode window so a looping core can
  never run indefinitely. `TimingPolicy.plan` carries this through `usesNativeEnding`. SID
  metadata currently reports no natural duration, so its normal non-Long-Play window is the
  shared unknown-duration setting rather than a file-derived length.
- `appliesFadeInternally` distinguishes cores with native fade (libgme, libvgm) from PCM
  streamers (Highly Complete, vgmstream, lazyusf, playpsf, OpenMPT) that delegate the fade to
  `PlaybackSession`.
- Standard audio, including FLAC, is finite and never supports Long Play. Its AVAudioFile reader
  is reopened for track starts and seeks so the macOS compressed-file reader and converter state
  are reset without using the unsupported FLAC `framePosition` setter.
- Highly Complete bridge calls are serialized through one gate. Its native GBA rate may change
  while mGBA runs, so the bridge resamples to VGMBoy's requested output rate and reports output-frame position.
- 2SF bridge calls are serialized because the DS core is process-global. `PlaybackSession` calls
  `close()` before constructing a replacement decoder, so teardown never depends on ARC timing.
- Audio Overload's QSF engine and dependency directory are process-global. `QSFDecoder` holds one
  fail-fast exclusive lease for the complete native-handle lifetime; concurrent live playback,
  AAC export, or structure inspection returns an explicit busy error instead of sharing emulator
  state. `close()` releases the native engine and lease before replacement.
- Bridges are owned by VGMBoy (`Sources/C<Core>`). Shared upstream source and compatibility patches
  live in VGMBoy's `vendor/` and `patches/` inputs; dependency archives are built and staged here,
  never separately in CocoaSpice or SPCBoy. Symbol prefixes are per-core (`vgmboy_play_psf_*`, etc.).

## Failure Boundaries

- Bridge `create` failures surface as localized decoder errors; decode-time bridge failures return
  silence for that chunk rather than crashing the transport.

## Files

- [FormatRegistry.swift](/Users/john/Downloads/Code/VGMMan/VGMBoy/Sources/VGMBoyKit/FormatRegistry.swift)
- [AudioDecoder.swift](/Users/john/Downloads/Code/VGMMan/VGMBoy/Sources/VGMBoyKit/AudioDecoder.swift)
- [GMEDecoder.swift](/Users/john/Downloads/Code/VGMMan/VGMBoy/Sources/VGMBoyKit/GMEDecoder.swift)
- [SIDDecoder.swift](/Users/john/Downloads/Code/VGMMan/VGMBoy/Sources/VGMBoyKit/SIDDecoder.swift)
- [OpenMPTDecoder.swift](/Users/john/Downloads/Code/VGMMan/VGMBoy/Sources/VGMBoyKit/OpenMPTDecoder.swift)
- [VGMDecoder.swift](/Users/john/Downloads/Code/VGMMan/VGMBoy/Sources/VGMBoyKit/VGMDecoder.swift)
- [HighlyCompleteDecoder.swift](/Users/john/Downloads/Code/VGMMan/VGMBoy/Sources/VGMBoyKit/HighlyCompleteDecoder.swift)
- [TwoSFDecoder.swift](/Users/john/Downloads/Code/VGMMan/VGMBoy/Sources/VGMBoyKit/TwoSFDecoder.swift)
- [VgmstreamDecoder.swift](/Users/john/Downloads/Code/VGMMan/VGMBoy/Sources/VGMBoyKit/VgmstreamDecoder.swift)
- [LazyUSFDecoder.swift](/Users/john/Downloads/Code/VGMMan/VGMBoy/Sources/VGMBoyKit/LazyUSFDecoder.swift)
- [PlayPSFDecoder.swift](/Users/john/Downloads/Code/VGMMan/VGMBoy/Sources/VGMBoyKit/PlayPSFDecoder.swift)
- [QSFDecoder.swift](/Users/john/Downloads/Code/VGMMan/VGMBoy/Sources/VGMBoyKit/QSFDecoder.swift)
