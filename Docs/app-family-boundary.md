# App Family Boundary

## Scope

VGMBoy owns the shared playback core, decoder integration, dependency staging, and scanner-facing
inspection builds for the CocoaSpice, SPCBoy WK, and ScanSong products.

## Ownership

- CocoaSpice is the native SwiftUI playlist frontend. It reads the MediaScanner catalog and links
  `VGMBoyKit` in-process.
- SPCBoy WK is the active native WebKit frontend. It reads the MediaScanner catalog and links the
  shared VGMBoy core through its native endpoint bridge. The original Electron SPCBoy is archived
  and is not an active consumer of VGMBoy changes.
- ScanSong is the native catalog-management app and the sole schema-23 catalog writer. It bundles
  the inspection executables produced through VGMBoy's scanner-plugin build boundary.
- VGMBoy is database-free and never owns a playlist, catalog mutation, or frontend window.

## Invariants

- CocoaSpice and SPCBoy WK open the selected catalog read-only; all catalog writes belong to ScanSong.
- Frontends own queue policy, presentation, archive materialization, and host-specific process
  boundaries. VGMBoy owns format admission, decoder selection, timing, transport, equalization,
  and audio output.
- ScanSong receives scanner executables from VGMBoy and never invokes a player frontend or a
  frontend-owned plugin helper.
- Shared decoder source, compatibility patches, and dependency builds live in VGMBoy. The
  frontends do not carry duplicate decoder source trees or plugin build scripts.

## Files

- [Package.swift](/Users/john/Downloads/Code/VGMMan/VGMBoy/Package.swift)
- [build-app.sh](/Users/john/Downloads/Code/VGMMan/VGMBoy/build-app.sh)
- [build-integration.md](/Users/john/Downloads/Code/VGMMan/VGMBoy/ai/subsystem-agent/build-integration.md)
- [CocoaSpice project info](/Users/john/Downloads/Code/VGMMan/CocoaSpice/ai/project-info.md)
- [SPCBoy WK project info](/Users/john/Downloads/Code/VGMMan/SPCBoyWK/ai/project-info.md)
- [ScanSong project info](/Users/john/Downloads/Code/VGMMan/MediaScanner/ai/project-info.md)
