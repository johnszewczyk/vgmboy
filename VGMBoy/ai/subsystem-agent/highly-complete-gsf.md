# Highly Complete GSF Bridge

## Scope

`gsf` and `minigsf` decoding through PSFLib and headless mGBA.

## Ownership

`CHighlyComplete` owns PSF dependency resolution, in-memory GBA ROM assembly, mGBA lifecycle,
native-rate resampling, and bridge metadata. `HighlyCompleteDecoder` owns the VGMBoy decoder
contract and serializes every bridge call through its dedicated gate.

## Invariants

- Decoder facts are read only after playback session construction; they are never surfaced as a
  catalog or inspection API.
- miniGSF requires its sibling `.gsflib` dependencies beside the selected file.
- After mGBA `loadROM`, the ROM `VFile` belongs to mGBA; bridge teardown never closes it again.
- mGBA's live native rate is resampled into the fixed VGMBoy output rate. Played frames and seek
  milliseconds are always expressed in output frames.
- The bridge has no internal fade; `PlaybackSession` applies the capped-window fade exactly once.

## Failure Boundaries

- Missing or unresolved PSF dependencies are explicit bridge errors.
- Render failures return silence for that chunk; they do not crash the transport.
- The native bridge is not assumed thread-safe. Do not bypass the Swift bridge gate.

## Files

- [HighlyCompleteDecoder.swift](../../Sources/VGMBoyKit/HighlyCompleteDecoder.swift)
- [highlycomplete_bridge.cpp](../../Sources/CHighlyComplete/highlycomplete_bridge.cpp)
- [Package.swift](../../Package.swift)
