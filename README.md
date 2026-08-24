# VGMBoy

VGMBoy is the shared macOS game-music playback and inspection-plugin core for the
CocoaSpice/SPCBoy/ScanSong app family. It owns format routing, decoder integration, timing, Long Play,
tempo, fade, ten-band EQ, and the audio device. Its command-line tool, small
SwiftUI test app, and CocoaSpice are clients of the same `VGMBoyKit` transport.

`VGMBoyEndpointCore` is the small, platform-neutral endpoint map for those
clients. It names the shared playback, audio, diagnostics, and export routes;
the typed `PlaybackControlProtocol` remains the native Swift payload contract.

VGMBoy is intentionally database-free. MediaScanner remains the sole schema-23
catalog writer. CocoaSpice links `VGMBoyKit` in-process; SPCBoy WK links the
same core directly through its native endpoint adapter. The legacy Electron
SPCBoy path remains separate until it is retired; ScanSong bundles the
inspection executables produced by VGMBoy.

## How the app family works

| Component | Responsibility |
| --- | --- |
| MediaScanner | Publishes the shared SQLite catalog and stored sidebar/playlist projections; bundles VGMBoy inspection plugins for intake. |
| CocoaSpice | Reads that catalog, owns playlist and queue policy, materializes selected archive members, and forwards playback controls to bundled VGMBoyKit. |
| VGMBoyKit | Decodes a supplied playable path, owns timing/EQ/audio output, and reports status and natural end. |
| SPCBoy WK | Reads the same catalog independently, materializes files app-side, and sends playback commands through the shared VGMBoy endpoint surface. |

VGMBoy is not a daemon. Every host bundles the core into its own process. A host supplies a path
and subtrack index through PlaybackControl v1; VGMBoy never reads or writes catalogs and never
chooses the next queue item.

## Active decoder plugins

This is the exhaustive list of decoder plugins instantiated by
`DecoderFactory` in the current project. “Revision” is used where the upstream
project provides no release version for the exact source checked out here.
Bridge code in `Sources/C<Core>/` belongs to VGMBoy; it does not fork any of
the upstream decoders.

| Plugin | Current version or revision | Upstream repository or home | Formats routed here | VGMBoy integration |
| --- | --- | --- | --- | --- |
| [Game Music Emu / libgme](https://github.com/libgme/game-music-emu) | 0.6.5 (Homebrew `game-music-emu` / `pkg-config`) | [github.com/libgme/game-music-emu](https://github.com/libgme/game-music-emu) | AY, GBS, HES, KSS, NSF, NSFE, SAP, SPC | `CGameMusicEmu` system-library target; native long-play and tempo support. |
| [libvgm](https://github.com/ValleyBell/libvgm) | `867223e7c33d63de115d1ab955f784c44f19040a` | [github.com/ValleyBell/libvgm](https://github.com/ValleyBell/libvgm) | VGM, VGZ, GYM, S98, DRO | `CLibVGM` bridge; source and static-library build are owned by VGMBoy. |
| [Highly Complete](https://github.com/mgba-emu/mgba) (mGBA + PSFLib) | VGMBoy `vendor/mgba` snapshot; this checkout does not record an independent upstream revision | [github.com/mgba-emu/mgba](https://github.com/mgba-emu/mgba) | GSF, miniGSF | `CHighlyComplete` bridge; PSFLib resolves the complete miniGSF chain, then mGBA runs the assembled GBA ROM. The bridge resamples mGBA's live native rate into VGMBoy's fixed output rate. |
| 2sf2wav | VGMBoy `vendor/2sf2wav` snapshot; this checkout does not record an independent upstream revision or home site | — | 2SF, mini2SF | `C2SF` bridge over the static DS core. It validates relative mini2SF libraries and explicitly tears down process-global DS state before any replacement decoder is created. |
| [vgmstream](https://github.com/vgmstream/vgmstream) | `807b4948cfc1de0cd90e377e9c56f74664c54a1c` + shared compatibility patch | [github.com/vgmstream/vgmstream](https://github.com/vgmstream/vgmstream) / [vgmstream.org](https://vgmstream.org) | ADX, XA, AT3, FSB, VAG, AIFC, OGG, and the other extensions in `FormatRegistry.vgmstreamExtensions` | `CVGmstream` bridge plus the VGMBoy-built `vgmstream-cli` scanner plugin; built with FFmpeg and Vorbis support. |
| [lazyusf2](https://gitlab.com/kode54/lazyusf2) | `421f00bcaa1988b8e1825e91780129f24fbd1aa0` | [gitlab.com/kode54/lazyusf2](https://gitlab.com/kode54/lazyusf2) | USF, miniUSF | `CLazyUSF` bridge; companion `.usflib` files must be present beside a miniUSF. These streams have no natural ending, so VGMBoy always applies a finite playback window. |
| [Play!](https://github.com/jpd002/Play-) PSF core | `50aedca2639521bc498ace0b2be1ea012801a86a` + VGMBoy PSF-core-only patch | [github.com/jpd002/Play-](https://github.com/jpd002/Play-) / [purei.org](https://purei.org) | PSF, miniPSF, PSF2, miniPSF2 | `CPlayPSF` bridge over the `PsfCore` static archive. The required patch is `patches/play-psfcore-only.patch`; companion `.psflib` files must be present beside a miniPSF. |
| [Audio Overload SDK](https://github.com/nmlgc/aosdk) QSF engine | shallow source snapshot under `vendor/aosdk` | [github.com/nmlgc/aosdk](https://github.com/nmlgc/aosdk) | QSF, miniQSF | `CQSF` provides native PCM, seeking, timing tags, and `.qsflib` dependency resolution. Because the engine is process-global, one decoder holds an exclusive lifetime lease and concurrent QSF work fails explicitly. The same engine builds the `vgmboy-qsf-inspect` scanner plugin. |
| [libsidplayfp](https://github.com/libsidplayfp/libsidplayfp) | Homebrew `libsidplayfp` build | [github.com/libsidplayfp/libsidplayfp](https://github.com/libsidplayfp/libsidplayfp) | SID | `CSIDPlayFP` bridge; SID output joins the same direct audio transport. |
| [libopenmpt](https://lib.openmpt.org/libopenmpt/) | Homebrew `libopenmpt` build | [github.com/OpenMPT/openmpt](https://github.com/OpenMPT/openmpt) / [lib.openmpt.org](https://lib.openmpt.org/libopenmpt/) | MOD, XM, IT, S3M and registered tracker modules | `COpenMPT` bridge; modules use the same direct audio transport. |

`StandardAudioDecoder` uses AVFoundation for ordinary macOS-admitted formats. The separate
`CFFmpeg` bridge handles MP2 and TAK without a frontend process fallback.

## Direct build and platform dependencies

These are direct inputs to the current build rather than decoder plugins. They
are listed here so the native boundary is inspectable; VGMBoy does not declare
or install a broad package manager graph of its own.

| Dependency | Version or source state | Role |
| --- | --- | --- |
| VGMBoy shared source garden | `vendor/` in this checkout | Canonical upstream source inputs and compatibility patches for every VGMBoy bridge and scanner-facing plugin. |
| [mGBA](https://github.com/mgba-emu/mgba) | VGMBoy `vendor/mgba` snapshot; no independent revision recorded by this checkout | Linked by the Highly Complete bridge and prepared for ScanSong through `scripts/build-scanner-plugins.sh`. |
| 2sf2wav | VGMBoy `vendor/2sf2wav` snapshot; no independent revision recorded by this checkout | Built as `lib2sf.a` through `scripts/build-2sf.sh` and linked by the 2SF bridge. |
| Swift Package Manager | tools version 6.1; Swift language mode 6 | Builds `VGMBoyKit`, `vgmboy-cli`, and the `VGMBoy` test app. |
| [CMake](https://cmake.org/) | 4.4.2 in the development environment | Builds libvgm, vgmstream, and the Play! PSF core through VGMBoy scripts. |
| [FFmpeg](https://ffmpeg.org/) | 8.1.2_1 (`libavcodec` ABI 62.28.102, `libavformat` 62.12.102, `libavutil` 60.26.102, `libswresample` 6.3.102) | Enabled in the vgmstream static build and linked directly by `CFFmpeg` for MP2/TAK playback. |
| [libvorbis](https://xiph.org/vorbis/) | 1.3.7 | Enabled in the vgmstream static build. |
| [libogg](https://xiph.org/ogg/) | 1.3.6 | Enabled in the vgmstream static build. |
| PSFLib source snapshot | VGMBoy-managed `vendor/psflib`; no independent upstream revision is pinned in this checkout | Compiled with lazyusf2 to resolve PSF-family dependency chains. |
| macOS frameworks and system libraries | macOS 26.0 deployment target; SDK-supplied versions | `AVFoundation`, `AudioToolbox`, `AppKit`, `SwiftUI`, plus `iconv`, zlib, and bzip2 required by the direct bridges. |

The Play! archive also consolidates its own upstream implementation
dependencies (including PsfCore support libraries). VGMBoy instantiates only
the single Play! PSF plugin above; it does not separately link or expose those
transitive components as decoder plugins.

## Build and run

From this directory:

```bash
git submodule update --init --recursive
swift test --package-path . --disable-sandbox
./launch.sh
```

`./launch.sh` performs a clean release build, prepares any missing upstream
static libraries through `scripts/build-dependencies.sh`, packages `VGMBoy.app`, and opens it. For ScanSong's external
inspection plugins, use `scripts/build-scanner-plugins.sh`. The
CLI product is named `vgmboy-cli` specifically to avoid colliding with the app
name on case-insensitive filesystems.

## Project boundaries

- `VGMBoyKit` owns decoding, playback timing, and the macOS audio device.
- The CLI and SwiftUI app are test skins over that one core.
- MediaScanner remains the only schema-23 catalog writer.
- CocoaSpice links VGMBoyKit directly; SPCBoy runs the same code through its
  private bundled bridge. Neither host has a second playback engine.

For current engineering constraints and routing, see
[ai/project-info.md](ai/project-info.md) and
[ai/subsystem-agent/](ai/subsystem-agent/).
