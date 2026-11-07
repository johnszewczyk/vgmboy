# Playback Admission

## Scope

SB2's app-specific projection of the shared VGMBoy playback registry and its
native request boundary.

## Invariants

- SB2 filters experimental BareSkin backends `uacngb` and `ares-snes` from the
  playback capability manifest.
- SB2 rejects `.ngbd` and `.snesstate` payloads at playback and AAC-export
  entry points, including when they are members of a `.uac` archive.
- Do not remove or alter these shared VGMBoy decoders to change SB2 policy.
  BareSkin playback, capture, and core work belongs in UAC Play and UAC Rips;
  a later player integration requires separate review.
- The SB2 app bundle does not stage the experimental Ares SNES helper.

## Files

- `Sources/SB2/WKNativeBridge.swift`
- `Sources/SB2/WKPlaybackBridge.swift`
- `build.sh`
