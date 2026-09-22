# Metadata Reader Boundary

## Scope

The shared `MetaManCore` API and its integration boundary. The per-format
facts and bounds are in [FORMAT-LAYOUTS.md](../../FORMAT-LAYOUTS.md).

## Ownership

- `MetaManCore.supportedFormats` is the explicit registered reader set.
  VGMBoy playback support and ScanSong admission are separate coverage facts.
- `read(fileURL:)` returns one metadata document; `readResult(fileURL:)`
  returns the ordered package/track result where a format has multiple tracks.
- ScanSong supplies source and context, adapts the ordered result, and owns
  catalog rows. VGMBoy owns playback decoders and scanner helpers that are
  still required for structure or dependency validation.

## Invariants

- The core depends on no ScanSong, VGMBoyKit, frontend, or emulator target.
  Its local package dependency is `UACWrapperCore`; system zlib and Apple's
  AVFoundation are explicit platform inputs. A compressed UAC manifest uses a
  caller-supplied bounded callback; the CLI's external `zstd` process is not
  a core dependency.
- Readers bound source lengths, offsets, counts, pointers, and decompression
  before deriving fields. Original bytes, ordered/repeated tags, unknown keys,
  native timing, and diagnostics remain available when the source supplies
  them. Normalized fields never replace preserved native facts.
- A format alias with a different header is not silently classified as the
  registered format. Unsupported or malformed data returns a typed error or
  diagnostic; it does not become an invented track.
- A reader's complete known metadata structure is a separate claim from
  audible playback. A decoder oracle is test-only, and its own defects are
  not automatically a metadata specification.
- A source reader change that alters ScanSong's catalog projection requires
  an adapter regression and a representative fixture. Format support claims
  distinguish contract tests from packaged and live-fixture evidence.

## Files

- [MetaManCore.swift](../../Sources/MetaManCore/MetaManCore.swift)
- [MetadataDocument.swift](../../Sources/MetaManCore/MetadataDocument.swift)
- [Package.swift](../../Package.swift)
- [Scanner adapter](../../../ScanSong/Sources/ScanSongKit/MetaManMetadataAdapter.swift)
