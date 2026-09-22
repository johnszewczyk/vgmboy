# Metadata Inspection

## Scope

The `metaman` command exposes MetaMan's registered native metadata readers.

## Commands

- `metaman read <file>` prints one metadata document as formatted JSON.
- `metaman read-tracks <file>` prints the ordered result, including track
  documents where the source declares multiple tracks.
- An unsupported or malformed source reports an error on standard error and
  exits unsuccessfully. The command does not modify the source.

## Coverage

The supported-format list is explicit in `MetaManCore`; it is not every format
ScanSong can catalog or VGMBoy can play. Compressed UAC manifests use the CLI's
external `zstd` tool, while uncompressed manifests do not need it.

## Files

- [main.swift](../../Sources/metaman/main.swift)
- [UACManifestZstandardDecoder.swift](../../Sources/metaman/UACManifestZstandardDecoder.swift)
