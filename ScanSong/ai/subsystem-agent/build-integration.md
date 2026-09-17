# Build Integration

## Scope

Fresh packaging and runtime assembly for ScanSong's native app bundle and its external inspection
executables.

## Ownership

- VGMBoy owns decoder source, compatibility patches, dependency archives, and scanner-plugin builds.
- VGMBoy's [plugin milestone manifest](/Users/john/Downloads/Code/VGMMan/VGMBoy/Docs/plugin-versions.json)
  and [read-only audit script](/Users/john/Downloads/Code/VGMMan/VGMBoy/scripts/audit-plugin-versions.sh)
  are the source of truth for upstream revision review; ScanSong does not keep a second version list.
- ScanSong depends on VGMBoy's lightweight `VGMBoyFormatCore` product for typed
  format admission; it does not link VGMBoyKit or native decoders for its
  in-process metadata readers. `VGMBoySNDH` is a test-only decoder oracle.
- ScanSong consumes the local sibling `MetaManCore` Swift package for APE, ADX,
  AUS, ATRAC3, Sony MSF/SSHD/XA, headerless PlayStation MIB, Nintendo DTK and
  TXTH-described IMA ADP, CRI AHX, Konami Saturn DVI, Konami/SNK SVAG and XMD,
  Nintendo DSP/RS03/THP, Nintendo DS STRM, SID, SPC, SNDH, S98, VGM/VGZ,
  UAC, PSF-family, GSF, and QSF metadata. MetaManCore owns bounded VGZ gzip
  expansion and UAC manifest interpretation; ScanSong supplies the bounded
  Zstandard callback for compressed UAC manifests. MetaManCore has no VGMBoy,
  ScanSong, or playback-decoder dependency; test-only libvgm comparisons stay
  in ScanSong.
- `ScanSong/build-app.sh` asks VGMBoy to build the vgmstream CLI, MDX inspector, and UADE-backed Amiga inspector,
  then copies those products into the ScanSong bundle.
- `ScanSong/launch.sh` packages a fresh app, asks the older ScanSong process to
  close through `SIGTERM`, and refuses to open it while that process remains.

## Invariants

- ScanSong never reaches into CocoaSpice, SPCBoy, or a frontend-owned helper path.
- The app bundle contains the VGMBoy-built `vgmstream-cli`,
  `vgmboy-mdx-inspect`,
  `vgmboy-amiga-inspect` product at the paths
  expected by the scanner adapters.
- `build-app.sh` removes `.build` before a release build so stale scanner binaries cannot survive
  a fresh packaging run.
- The VGMBoy scanner-plugin helper creates its destination before copying
  helpers, pins CMake to the active Xcode macOS SDK, and includes that SDK path
  in the build signature. This keeps CMake's compiler test on the same SDK as
  the selected linker.
- A missing inspection executable is a typed adapter failure; the scanner does not invent a row or
  invoke another application as a fallback. MetaManCore reads GSF/miniGSF and
  QSF/miniQSF in-process; neither requires a bundled Highly Complete or QSF
  inspection executable. APE is also read in-process. MDX and Amiga
  inspectors use respective VGMBoy per-format inspection targets and native
  bridges, not VGMBoyKit. Scanner-plugin preparation builds the scanner handoff
  directly; it does not invoke VGMBoy's broad playback dependency builder or
  stage unrelated mGBA/QSF playback cores.
- CRI/Monster ADX uses MetaManCore's in-process header reader and never starts
  `vgmstream-cli`. `.adx` content without a CRI or Monster Games signature
  remains on the vgmstream route; the helper also remains necessary for the
  other registered vgmstream formats.
- Atomic Planet AUS metadata uses MetaManCore's in-process header reader and
  never starts `vgmstream-cli` for recognized `AUS ` content; other `.aus`
  aliases retain the helper route.
- Sony CD-XA sector streams use MetaManCore's in-process structure/timing
  reader and never start `vgmstream-cli`; other formats sharing `.xa` remain on
  that helper route.
- UAC catalog rows use MetaManCore package/member documents. ScanSong decompresses
  only a compressed manifest frame through its bounded host callback; catalog
  scans never decompress, hash, or inspect the TAR/audio payload.
  Compressed manifests require the `zstd` command-line tool on `PATH` or at a
  supported Homebrew/system path; ScanSong does not bundle it. Uncompressed
  manifests do not require zstd.
- Recognized Sony MSF files use MetaManCore's in-process container/metadata
  reader and never start `vgmstream-cli`; `MSF ` and other `.msf` aliases retain
  the helper route.
- Known Konami/SNK SVAG signatures use MetaManCore's in-process metadata reader
  and never start `vgmstream-cli`; other `.svag` aliases retain the helper route.
- Validated Sony SSHD/ADS headers use MetaManCore's in-process metadata reader
  and never start `vgmstream-cli`; nonmatching `.ads` aliases retain the helper
  route.
- Validated headerless PlayStation `.mib` payloads use MetaManCore's in-process
  PS-ADPCM probe and timing reader and never start `vgmstream-cli`; invalid
  `.mib` probes retain the helper route. The distinct `.mib`/`.mih` bank layout
  is not silently classified as headerless MIB.
- Validated headerless Nintendo DTK and exact TXTH-described IMA `.adp`
  payloads use MetaManCore's in-process reader and never start `vgmstream-cli`.
  Unknown `.adp` aliases retain the helper route; the hidden TXTH sidecar is
  metadata context and never becomes a duplicate scan item.
- Validated CRI AHX `.ahx` payloads use MetaManCore's bounded header and
  fixed-bitrate duration reader and never start `vgmstream-cli`; malformed or
  unrelated `.ahx` aliases retain the helper route.
- Validated Konami Saturn `DVI.` `.dvi` payloads use MetaManCore's bounded
  header/timing reader and never start `vgmstream-cli`; Capcom `IDVI` aliases,
  incomplete payloads, and other unknown `.dvi` files retain the helper route.
- Bink `.bika` metadata is read through MetaManCore's complete container
  header/frame/packet walk; Bink playback remains in VGMBoy and `.bik`/`.bk2`
  movie inspection remains on vgmstream.
- Validated Konami XMD v1/v2 headers use MetaManCore's in-process reader and
  never start `vgmstream-cli`; unrecognized `.xmd` payloads retain the helper
  route.
- Standard Nintendo DSPADPCM, Retro Studios `RS03`, and Nintendo THP-audio
  signatures use MetaManCore's in-process header readers and never start
  `vgmstream-cli`; other `.dsp` aliases retain the helper route.
- Validated Nintendo DS standard `STRM`/`HEAD`/`DATA` and FFTA2 `RIFF`/`IMA `
  content use MetaManCore's in-process header/timing readers and never start
  `vgmstream-cli`; other `.strm` aliases retain the helper route.
- SPC ID666/xID6 blocks, S98 header/tags/event timing, VGM/VGZ headers/GD3/sample
  timing, and PSF-family `[TAG]` fields are read by MetaManCore; these routes do
  not invoke playback cores for metadata. SPC playback remains in VGMBoy.

## Failure Boundaries

- Dependency or plugin build failure stops packaging and leaves the previous installed app intact.
- Retiring a running development app is cooperative: `SIGTERM` enters the
  app's termination delegate, and launch waits for the scan/maintenance close
  boundary instead of replacing a live scanner process.
- An unavailable staged inspector is reported by the scanner adapter and does not become a player
  launch or permission request.
- SNDH metadata is read through MetaManCore, including its bounded ICE!
  expansion. The old `VGMBoySNDH` API is retained only by ScanSong tests as a
  reader oracle; PSGPlay remains in VGMBoy for playback.
- MDX metadata is read through the VGMBoy-built `vgmboy-mdx-inspect` process;
  ScanSong owns only route registration and catalog projection.
- Amiga metadata is read through the VGMBoy-built `vgmboy-amiga-inspect` process;
  ScanSong owns only prefix admission, archive materialization, and catalog projection.
- APE metadata is read by MetaManCore's direct header/tag reader; FFmpeg
  remains in VGMBoy for playback and is not an APE scanner requirement.
- CRI/Monster ADX metadata is read by MetaManCore's direct header/timing reader; vgmstream
  remains a VGMBoy playback route and a scanner helper for other formats.
- Atomic Planet AUS metadata is read by MetaManCore's direct header/timing
  reader; vgmstream remains the fallback for other `.aus` payloads and scanner
  support for other formats.
- Sony MSF metadata is read by MetaManCore's direct header/frame reader;
  vgmstream remains the fallback for non-Sony `.msf` aliases and scanner
  support for other formats.
- Konami/SNK SVAG metadata is read by MetaManCore's direct header reader;
  vgmstream remains the fallback for unknown `.svag` aliases and scanner
  support for other formats.
- GSF/miniGSF metadata and structure are read by MetaManCore's complete
  PSF/GSF parser; ScanSong adapts the document. Highly Complete/mGBA remains a
  VGMBoy playback route, not a scanner process or runtime link.
- QSF/miniQSF metadata and structure are read by MetaManCore's complete
  PSF/QSound parser; AOSDK remains a VGMBoy playback route, not a scanner process.

## Files

- [build-app.sh](/Users/john/Downloads/Code/VGMMan/ScanSong/build-app.sh)
- [launch.sh](/Users/john/Downloads/Code/VGMMan/ScanSong/launch.sh)
- [ScannerInspectors.swift](/Users/john/Downloads/Code/VGMMan/ScanSong/Sources/ScanSongKit/ScannerInspectors.swift)
- [VGMBoy build integration](/Users/john/Downloads/Code/VGMMan/VGMBoy/ai/subsystem-agent/build-integration.md)
