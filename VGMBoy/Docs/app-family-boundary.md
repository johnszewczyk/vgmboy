# App Family Boundary

## Scope

VGMBoy owns the shared playback core, decoder integration, dependency staging, and scanner-facing
inspection builds for the CocoaSpice, SPCBoyWK, ViewBoy, and ScanSong products.

## Ownership

- CocoaSpice is the native SwiftUI playlist frontend. It reads the ScanSong catalog and links
  `VGMBoyKit` in-process.
- SPCBoy WK is the active native WebKit frontend. It reads the ScanSong catalog and links the
  shared VGMBoy core through its native endpoint bridge. The original Electron SPCBoy is archived
  and is not an active consumer of VGMBoy changes.
- ViewBoy is a separate active WebKit frontend with its own bundle identity and phosphor display
  layer. It reads the same catalog and links the shared core through its native bridge.
- ScanSong is the native catalog-management app and the sole schema-23 catalog writer. It bundles
  the inspection executables produced through VGMBoy's scanner-plugin build boundary.
- VGMBoy is database-free and never owns a playlist, catalog mutation, or frontend window.

## Invariants

- CocoaSpice, SPCBoyWK, and ViewBoy open the selected catalog read-only; all catalog writes belong
  to ScanSong.
- Frontends own queue policy, presentation, archive materialization, and host-specific process
  boundaries. VGMBoy owns format admission, decoder selection, timing, transport, equalization,
  and audio output.
- ScanSong receives scanner executables from VGMBoy and never invokes a player frontend or a
  frontend-owned plugin helper.
- ScanSong consumes complete decoder-independent format metadata through
  MetaManCore. VGMBoy owns playback decoders and the narrow inspection
  executables required for formats that still need decoder-backed enumeration;
  ScanSong does not link VGMBoyKit.
- Shared decoder source, compatibility patches, and dependency builds live in VGMBoy. The
  frontends do not carry duplicate decoder source trees or plugin build scripts.

## Files

- [Package.swift](../Package.swift)
- [build-app.sh](../build-app.sh)
- [build-integration.md](../ai/subsystem-agent/build-integration.md)
- [CocoaSpice project info](../../CocoaSpice/ai/project-info.md)
- [SPCBoy WK project info](../../SPCBoyWK/ai/project-info.md)
- [ViewBoy project info](../../ViewBoy/ai/project-info.md)
- [ScanSong project info](../../ScanSong/ai/project-info.md)
