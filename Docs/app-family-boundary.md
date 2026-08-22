# App Family Boundary

## Scope

VGMBoy owns the shared playback core, decoder integration, dependency staging, and scanner-facing
inspection builds for the CocoaSpice, SPCBoy, and ScanSong products.

## Ownership

- CocoaSpice is the native SwiftUI playlist frontend. It reads the MediaScanner catalog and links
  `VGMBoyKit` in-process.
- SPCBoy is the Electron frontend. It reads the MediaScanner catalog and bundles
  `vgmboy-electron-bridge` for playback.
- ScanSong is the native catalog-management app and the sole schema-23 catalog writer. It bundles
  the inspection executables produced through VGMBoy's scanner-plugin build boundary.
- VGMBoy is database-free and never owns a playlist, catalog mutation, or frontend window.

## Invariants

- CocoaSpice and SPCBoy open the selected catalog read-only; all catalog writes belong to ScanSong.
- Frontends own queue policy, presentation, archive materialization, and host-specific process
  boundaries. VGMBoy owns format admission, decoder selection, timing, transport, equalization,
  and audio output.
- ScanSong receives scanner executables from VGMBoy and never invokes a player frontend or a
  frontend-owned plugin helper.
- Shared decoder source, compatibility patches, and dependency builds live in VGMBoy. The
  frontends do not carry duplicate decoder source trees or plugin build scripts.

## Files

- [Package.swift](/Users/john/Downloads/Code/VGMBoy/Package.swift)
- [build-app.sh](/Users/john/Downloads/Code/VGMBoy/build-app.sh)
- [build-integration.md](/Users/john/Downloads/Code/VGMBoy/ai/subsystem-agent/build-integration.md)
- [CocoaSpice project info](/Users/john/Downloads/Code/CocoaSpice/ai/project-info.md)
- [SPCBoy project info](/Users/john/Downloads/Code/SPCBoy/ai/project-info.md)
- [ScanSong project info](/Users/john/Downloads/Code/MediaScanner/ai/project-info.md)
