# VGMBoy decoder and plugin catalog

This is the human-readable companion to
[`plugin-versions.json`](plugin-versions.json). The JSON manifest is the
machine-readable source of truth for pins, source identities, and review dates;
this page records what each input does at the VGMBoy and ScanSong boundaries.
It describes the current implementation, not a claim that every file in a
format family is playable.

Last reviewed: **2026-09-12**

## Decoder matrix

| ID | Source/version | Playback bridge | ScanSong boundary | Formats and special data |
| --- | --- | --- | --- | --- |
| `libgme` | Game Music Emu 0.6.5 through Homebrew | `CGameMusicEmu` | ScanSong tests only as a parity oracle; no production scanner link | Playback supports AY, GBS, HES, KSS, NSF, NSFE, SAP, SPC |
| `VGMBoyFormatDataCore` | Foundation-only shared readers | None | Direct byte metadata route | SPC ID666/xID6 and tagless defaults, AY, NSF/GBS/NSFE, SAP, HES/M3U, direct PSF family, VGM/VGZ, SID |
| `libvgm` | `867223e7c33d63de115d1ab955f784c44f19040a` | `CLibVGM` | Native libVGM route | GYM, S98, DRO |
| `psgplay` | `f2028e94e5f6c7b3b38c9f7b5e2e0e1939613c06` | `CPSGPlay` / `VGMBoySNDH` | Shared SNDH inspector | Atari ST SNDH; declared subtunes become playlist rows |
| `mdxmini` | `003531a471c1955f4ed4357d0e2a6cba809c34a0` plus vendored LZX code | `CMDX` | `vgmboy-mdx-inspect` | X68000 MDX and PDX; sibling banks, legacy `\name`, inner LZX 0.32/0.42 |
| `uade` | Homebrew UADE 3.05 | `CUADE` | `vgmboy-amiga-inspect` | Amiga EaglePlayer modules, TFMX, MED, and prefix-led replayers |
| `vgmstream` | `807b4948cfc1de0cd90e377e9c56f74664c54a1c` plus compatibility patch | `CVGmstream` | Bundled `vgmstream-cli` | Console streamed audio, TXTP, HD/HBD/IECS-related routes |
| `lazyusf2` | `421f00bcaa1988b8e1825e91780129f24fbd1aa0` | `CLazyUSF` | Native dependency-aware route | USF and miniUSF; `.usflib` companions |
| `play-psf` | `50aedca2639521bc498ace0b2be1ea012801a86a` plus PSF-core patch | `CPlayPSF` | Native PSF route | PSF, miniPSF, PSF2, miniPSF2; `.psflib` companions |
| `aosdk-qsf` | `e359a6e5154b2ba8499fb1f24a1f5f8a18538a61` plus lifecycle patch | `CQSF` | Playback only; ScanSong uses its own direct reader | QSF and miniQSF; `.qsflib` companions |
| `mgba` | mGBA 0.11.0 source snapshot; tree SHA-256 `b7b71f64dab500433f3662b818e3521cf67524dcdee1a9952c1f555629ff55c0` | `CHighlyComplete` | GSF playback only; ScanSong reads GSF containers directly | GSF and miniGSF playback; PSFLib assembles dependency chains. The shared dependency build still prepares mGBA as collateral; the scanner does not link or run it. |
| `2sf2wav` | DeSmuME 0.9.9 svn 4608 source snapshot; tree SHA-256 `c3e329f9cf72881d25dabb03b9a89ebd4125ca9bd6d44c26f642589c622a9fb7` | `C2SF` | Native 2SF route | 2SF and mini2SF; relative library dependencies |
| `psflib` | VGMBoy-managed source snapshot; tree SHA-256 `c3adb7ea371fbeeedc68b3747c314419b52d9cb46aa0d75f177f428bcdb7d021` | Used by PSF-family bridges | Dependency support, not a standalone route | PSF and GSF library resolution |
| `libsidplayfp` | Homebrew libsidplayfp 3.1.0 | `CSIDPlayFP` | Native SID route | SID |
| `libopenmpt` | Homebrew libopenmpt 0.8.9 | `COpenMPT` | `openmpt123`/module route | MOD, XM, IT, S3M, and registered tracker modules |
| `ffmpeg-audio` | Homebrew FFmpeg 8.1.2_1 | `CFFmpeg` | Playback only; ScanSong reads APE directly | APE (Monkey's Audio), MP2, and TAK; one finite playback stream |

The source tree digests for ordinary snapshots and the exact submodule commits
are recorded in [`vendor/PROVENANCE.md`](../vendor/PROVENANCE.md). Compatibility
patches are tracked in `patches/` and applied only at the disposable build
boundary where required.

## Plugin boundaries

### Game Music Emu (`libgme`)

AY, HES, KSS, SAP, SPC, NSF/GBS, and NSFE all have direct metadata routes in
ScanSong. AY's relative-pointer subtune table and native duration frames,
SAP's header/TIME fields, and HES's header/M3U mapping are read without
starting a core. The SPC route handles both ID666/xID6 tags and tagless
info-only defaults; the production ScanSong library, CLI, and app do not link
libgme. Tests retain it only as a reader-parity oracle. SPC playback remains
owned by VGMBoy's libgme integration. NSF/GBS headers have no authored
per-track names or finite timing, so their direct scanner route preserves the
documented unknown/default timing policy.

NSFE scanner metadata is fully extracted from its chunk structure. The direct
reader validates INFO/DATA/NEND, preserves AUTH/TLBL/TAUT/TIME/FADE/TEXT and
playlist order, and retains unknown optional chunks as raw facts. Its embedded
NSF payload remains playback data owned by the libgme-backed VGMBoy player.

### libVGM (`libvgm`)

libVGM remains the decoder route for GYM and S98. VGM/VGZ are a separate
direct `VGMBoyFormatDataCore` route for header, GD3, and timing facts. Tempo
support is exposed only for families where the bridge has verified it.

### PSGPlay (`psgplay`)

SNDH is executable Atari ST music data, so extension admission is not a promise
of conventional music or audible output. PSGPlay enumerates declared subtunes;
the scanner publishes contiguous zero-based track indices and repeats the
shared metadata for each row. A file that opens but produces no meaningful
audio remains a fixture-level compatibility result, not a reason to invent a
track or hide the source.

### mdxmini and X68000 MDX/PDX

An MDX is a sequenced X68000 music-driver file. A PDX is its native sample-bank
data, not an archive and not an independent playlist item. ScanSong resolves
case-insensitive sibling banks, including `.PDX.zst` wrappers, and materializes
the complete dependency set before invoking `vgmboy-mdx-inspect`.

The native boundary also handles collections where the MDX body or the entire
PDX payload is wrapped in X68000 LZX 0.32/0.42. The decoder expands that layer
only in scratch memory, preserves the original files, validates the decoded
length, and rejects malformed streams. A legacy leading backslash in a PDX
basename is normalized narrowly to a same-directory name; absolute and
traversal paths remain unsafe.

### UADE

UADE is used for Amiga replayer files that are identified by EaglePlayer or
other content-name conventions. Prefix-led names such as `mod.*` and `p4x.*`
are admitted through the shared `AmigaFormatManifest`, while an ordinary
`music.mod` remains an OpenMPT module. ScanSong materializes the complete
archive set so player and sample companions are available, then publishes
UADE's actual subsongs. The Homebrew runtime/data installation is required for
both playback and inspection.

### vgmstream

vgmstream owns streamed console/game audio and structured TXT/HD routes. The
scanner invokes its bundled CLI through a bounded process boundary and keeps
valid archive members when a different member fails. TXTP aliases and required
sidecars are materialized before inspection; successful archive members are not
expanded into useless file-list log output.

### PSF-family cores

Play!, Highly Complete/mGBA, LazyUSF, 2SF, and QSF have different native cores
but share a playback dependency principle: a mini format is playable only when
its required library chain is present and resolvable. ScanSong independently
validates GSF/miniGSF PSF containers, compressed payloads, segment bounds, and
the complete GSF library chain while reading authored metadata; it does not
construct an mGBA core. PSFLib remains part of VGMBoy playback bridges, and QSF
continues to resolve its own `.qsflib` data through AOSDK.

QSF has an explicit process-global lifetime lease because the native engine is
not safely reusable while another QSF instance owns its global state. This
lease applies to VGMBoy playback only; ScanSong validates QSF containers,
payloads, and library references directly without initializing the native core.

### SID and tracker modules

SID uses libsidplayfp through the shared transport. Tracker modules use
libopenmpt and are admitted as structurally known single rows unless the native
module exposes a different supported structure. Neither route converts source
modules to an intermediate audio file for cataloging.

## Build and runtime dependencies

These are build/runtime inputs rather than independent decoder plugins. Values
below describe the environment used for the current documentation pass; the
decoder pins remain in `plugin-versions.json`.

| Dependency | Current environment value | Role |
| --- | --- | --- |
| FFmpeg | 8.1.2_1 | `CFFmpeg` APE/MP2/TAK playback support and vgmstream build input; ScanSong reads APE header/tags directly |
| libvorbis | 1.3.7 | vgmstream Vorbis support |
| libogg | 1.3.6 | vgmstream Ogg support |
| CMake | 4.4.2 | libvgm, vgmstream, Play!, and mGBA builds |
| Swift Package Manager | tools version 6.1 | VGMBoyKit, app, CLI, and inspector products |
| macOS SDK | deployment target 26.0 | AVFoundation, AudioToolbox, AppKit, SwiftUI, iconv, zlib, bzip2 |

## Verification policy

Version review is advisory and read-only. Run
`scripts/audit-plugin-versions.sh` before a release and approximately every 90
days. A newer upstream milestone is not adopted until the affected source is
pinned, rebuilt, and checked against a representative format fixture.

The current focused evidence includes real MDX LZX bodies, whole-file LZX PDX
banks, legacy PDX dependency names, Amiga routing, scanner handoff products,
and the complete VGMBoy/ScanSong unit suites. Corpus claims remain limited to
the samples explicitly described in the README and format-accommodation notes.
