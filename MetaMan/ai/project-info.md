# Project Info

## Product

MetaMan owns decoder-independent metadata readers for game-music and audio
formats. Apps link `MetaManCore` directly; metadata inspection does not launch
playback decoders.

## Ownership

- `MetaManCore` parses format-native tags, source facts, timing, dependencies,
  and ordered track documents where the source format contains them.
- The command-line target is a thin inspection client.
- ScanSong adapts reader results into its schema-23 catalog. It owns discovery
  and catalog writes, not duplicate native parsers.
- VGMBoy owns playback and decoder-based inspection only where no complete
  direct metadata reader is available.

## Task Routing

- Supported readers, layouts, bounds, and method:
  [`FORMAT-LAYOUTS.md`](../FORMAT-LAYOUTS.md).
- Public result/document contract and implementation:
  `Sources/MetaManCore/`.
- Reader fixtures and unit contracts:
  `Tests/MetaManCoreTests/`.
- Scanner adaptation and catalog projection:
  [`../ScanSong/ai/subsystem-agent/format-accommodations.md`](../../ScanSong/ai/subsystem-agent/format-accommodations.md).

## Local Rules

- A format is supported only when its reader covers its complete known
  metadata structure and is bounded by declared input data.
- Preserve order, duplicate tags, unknown fields, original source values, and
  diagnostics when available; normalized common fields are additive.
- Reading and writing are separate capabilities. Do not claim write support
  without format-specific preservation and round-trip tests.
- Decoder comparisons are test oracles, not production fallbacks. GYM is not
  an extraction target.

## Human Docs

`README.md` is the package overview. The format map is maintained in
[`FORMAT-LAYOUTS.md`](../FORMAT-LAYOUTS.md).
