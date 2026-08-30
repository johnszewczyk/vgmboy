# VGMBoy decoder and plugin catalog

This is the human-readable companion to
[`plugin-versions.json`](plugin-versions.json). The JSON manifest is the
machine-readable source of truth for pins, source identities, and review dates;
this page records what each input does at the VGMBoy and ScanSong boundaries.
It describes the current implementation, not a claim that every file in a
format family is playable.

Last reviewed: **2026-08-30**

## Decoder matrix

| ID | Source/version | Playback bridge | ScanSong boundary | Formats and special data |
| --- | --- | --- | --- | --- |
| `libgme` | Game Music Emu 0.6.5 through Homebrew | `CGameMusicEmu` | Native libgme metadata route | AY, GBS, HES, KSS, NSF, NSFE, SAP, SPC |
| `libvgm` | `867223e7c33d63de115d1ab955f784c44f19040a` | `CLibVGM` | Native libVGM route | VGM, VGZ, GYM, S98, DRO |
| `psgplay` | `f2028e94e5f6c7b3b38c9f7b5e2e0e1939613c06` | `CPSGPlay` / `VGMBoySNDH` | Shared SNDH inspector | Atari ST SNDH; declared subtunes become playlist rows |
| `mdxmini` | `003531a471c1955f4ed4357d0e2a6cba809c34a0` plus vendored LZX code | `CMDX` | `vgmboy-mdx-inspect` | X68000 MDX and PDX; sibling banks, legacy `\name`, inner LZX 0.32/0.42 |
| `uade` | Homebrew UADE 3.05 | `CUADE` | `vgmboy-amiga-inspect` | Amiga EaglePlayer modules, TFMX, MED, and prefix-led replayers |
| `vgmstream` | `807b4948cfc1de0cd90e377e9c56f74664c54a1c` plus compatibility patch | `CVGmstream` | Bundled `vgmstream-cli` | Console streamed audio, TXTP, HD/HBD/IECS-related routes |
| `lazyusf2` | `421f00bcaa1988b8e1825e91780129f24fbd1aa0` | `CLazyUSF` | Native dependency-aware route | USF and miniUSF; `.usflib` companions |
| `play-psf` | `50aedca2639521bc498ace0b2be1ea012801a86a` plus PSF-core patch | `CPlayPSF` | Native PSF route | PSF, miniPSF, PSF2, miniPSF2; `.psflib` companions |
| `aosdk-qsf` | `e359a6e5154b2ba8499fb1f24a1f5f8a18538a61` plus lifecycle patch | `CQSF` | `vgmboy-qsf-inspect` | QSF and miniQSF; `.qsflib` companions |
| `mgba` | mGBA 0.11.0 source snapshot; tree SHA-256 `b7b71f64dab500433f3662b818e3521cf67524dcdee1a9952c1f555629ff55c0` | `CHighlyComplete` | `vgmboy-highly-complete-inspect` | GSF and miniGSF; PSFLib assembles dependency chains |
| `2sf2wav` | DeSmuME 0.9.9 svn 4608 source snapshot; tree SHA-256 `c3e329f9cf72881d25dabb03b9a89ebd4125ca9bd6d44c26f642589c622a9fb7` | `C2SF` | Native 2SF route | 2SF and mini2SF; relative library dependencies |
| `psflib` | VGMBoy-managed source snapshot; tree SHA-256 `c3adb7ea371fbeeedc68b3747c314419b52d9cb46aa0d75f177f428bcdb7d021` | Used by PSF-family bridges | Dependency support, not a standalone route | PSF and GSF library resolution |
| `libsidplayfp` | Homebrew libsidplayfp 3.1.0 | `CSIDPlayFP` | Native SID route | SID |
| `libopenmpt` | Homebrew libopenmpt 0.8.9 | `COpenMPT` | `openmpt123`/module route | MOD, XM, IT, S3M, and registered tracker modules |

The source tree digests for ordinary snapshots and the exact submodule commits
are recorded in [`vendor/PROVENANCE.md`](../vendor/PROVENANCE.md). Compatibility
patches are tracked in `patches/` and applied only at the disposable build
boundary where required.

## Plugin boundaries

### Game Music Emu (`libgme`)

libgme owns enumeration and timing for the console music families it supports.
ScanSong supplements it with direct fixed-header metadata where that is safe:
NSF/GBS text fields and SPC ID666/xID6 fields. SPC metadata does not start an
emulator. The decoder remains authoritative for SPC playback and timing checks.

### libVGM (`libvgm`)

libVGM handles register-stream formats such as VGM/VGZ, GYM, and S98. VGZ
headers and GD3/timing fields may be harvested directly, while GYM and S98
remain on the decoder route until a native reader is fixture-qualified. Tempo
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
but share a dependency principle: a mini format is accepted only when its
required library chain is present and validated. The scanner publishes the
actual decoded structure and timing, never a synthetic row for a missing
library. PSFLib is used by the PSF/GSF family adapters rather than exposed as a
user-selectable format; QSF resolves its own `.qsflib` data through AOSDK.

QSF has an explicit process-global lifetime lease because the native engine is
not safely reusable while another QSF instance owns its global state. The
scanner inspector and playback bridge both release that state deterministically.

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
| FFmpeg | 8.1.2_1 | `CFFmpeg` MP2/TAK support and vgmstream build input |
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
