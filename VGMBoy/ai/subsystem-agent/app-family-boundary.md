# App Family Boundary

## Scope

VGMBoy owns the shared playback core, decoder integration, archive preparation, dependency staging,
and scanner-facing inspection builds for the CocoaSpice, SB2, SBONLINE, ViewBoy,
LineBoy, and ScanSong products.

## Ownership

- CocoaSpice is the native SwiftUI playlist frontend. It reads the ScanSong catalog and links
  `VGMBoyKit` in-process.
- SB2 is the current SPCBOY WebKit frontend under development. It reads the
  ScanSong catalog and links the shared VGMBoy core through its native endpoint
  bridge. SPCBoyWK is retired; its source is preserved in a local recovery ZIP
  and Git history, and is no longer a maintained client.
- SBONLINE is the hosted SPCBOY web-player project and is separate from SB2's
  macOS app bundle. The production Django pages, account integration, streaming
  adapter, and deployment currently remain in MathBook's `private-admin/` app;
  see the [SBONLINE integration note](../../../SBONLINE/ai/subsystem-agent/integration-boundaries.md).
- ViewBoy is a separate active WebKit frontend with its own bundle identity and phosphor display
  layer. It reads the same catalog and links the shared core through its native bridge.
- ScanSong is the native catalog-management app and the sole schema-24 catalog writer. It bundles
  the inspection executables produced through VGMBoy's scanner-plugin build boundary.
- VGMBoy is database-free and never owns a playlist, catalog mutation, or frontend window.

## Invariants

- CocoaSpice, SB2, and ViewBoy open the selected catalog read-only; all catalog
  writes belong to ScanSong.
- Frontends own catalog selection, queue policy, presentation, durable settings, and cache policy.
  They pass VGMBoy a direct source path or an archive path plus selected member. VGMBoy owns
  archive inspection and preparation, UAC frame decompression, format admission, decoder
  selection, timing, transport, equalization, and audio output.
- `VGMBoyArchiveCore` is the one archive process, path-safety, UAC, and materialization engine used
  by playback and finite AAC export. FrontendCore's archive modules retain cache and artwork
  adapters; they are not alternate playback extractors.
- ScanSong receives scanner executables from VGMBoy and never invokes a player frontend or a
  frontend-owned plugin helper.
- ScanSong consumes complete decoder-independent format metadata through
  MetaManCore. VGMBoy owns playback decoders and the narrow inspection
  executables required for formats that still need decoder-backed enumeration;
  ScanSong does not link VGMBoyKit.
- Shared decoder source, compatibility patches, and dependency builds live in VGMBoy. The
  frontends do not carry duplicate decoder source trees or plugin build scripts.

## Files

- [Package.swift](../../Package.swift)
- [build-app.sh](../../build-app.sh)
- [build-integration.md](build-integration.md)
- [CocoaSpice project info](../../../CocoaSpice/ai/project-info.md)
- [ViewBoy project info](../../../ViewBoy/ai/project-info.md)
- [ScanSong project info](../../../ScanSong/ai/project-info.md)
