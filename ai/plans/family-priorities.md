# VGMMan family priorities

## Objective

Keep the game-music frontends on shared, tested catalog, archive, metadata,
queue, and playback boundaries. Each app remains a separate product and release
unit; the monorepo is the only source tree for maintained family code.

## Ownership

| Concern | Owner |
| --- | --- |
| Decoder-independent format metadata | MetaMan |
| Source discovery, inspection routing, and schema-24 catalog writes | ScanSong |
| UAC manifest, seek table, and reversible wrapper | UACMan |
| Read-only catalog access and browser projections | CatalogReader |
| Shared archive/cache, preferences, queue, and transport policy | FrontendCore |
| Playback admission, decoders, timing, transport, and audio output | VGMBoy |
| AppKit/SwiftUI presentation | CocoaSpice |
| Native WebKit presentation | SPCBoyWK |
| Phosphor WebKit presentation | ViewBoy |
| Electron SPCBoy | Recovery source and archive only; never a LaunchPad target |

## Format decisions

- MetaMan reads native metadata from existing source formats. ScanSong adapts
  those results to schema 24; UACMan can read and edit its own manifest without
  rewriting native source files.
- UAC remains a reversible wrapper around original source members with separate
  rich metadata and seekable Zstandard payloads. It does not claim to improve
  the underlying stream or create a native SPC successor.
- Native SPC capture/reconversion is closed. No emulator-generated SPC event
  stream is added to the supported format boundary.
- Do not add a second reader or playback decoder where an owning package already
  exposes the complete capability. Format inventories and byte-layout evidence
  live in MetaMan and VGMBoy’s canonical maps.

## Current verification gates

1. Keep `scripts/verify-family.sh` aligned with all maintained packages,
   renderer checks, and family apps. Run it before a family release and record
   current results in `../verification/family.md`.
2. Verify packaged launch and playback interactions separately from package
   tests. Current cross-app evidence and limits live in
   `../reports/frontend-parity.md`.
3. Run audio-output/AAC integration checks on a host with a working CoreAudio
   device and encoder. Host-only failures must remain identified as environment
   gaps until that boundary is exercised successfully.
4. Add or restore real archive fixtures for RE2/AAC, Doom transitions, and
   Amiga LHA before claiming those packaged playback paths. Keep other missing
   format fixtures identified in the owning format notes.

## Contribution rule

Route each change to its owning package. Keep user-visible behavior in the
app’s `ai/subsystem-human/` notes and engineering constraints in focused
`ai/subsystem-agent/` notes. Update this plan only when ownership or the family
gates materially change; Git history retains prior implementation work.
