# VGMMan

VGMMan is the single Git repository for the game-music application family.
Every child directory keeps its own package boundary, build script, and release
boundary while sharing the family root's history.

## Projects

- `VGMBoy`: playback core, decoder routing, timing, audio output, and shared
  playback controls.
- `CocoaSpice`: native macOS playlist frontend.
- `SPCBoyWK`: native WebKit frontend. The older `SPCBoy` Electron frontend is
  retained separately as a deprecated historical project.
- `ScanSong`: ScanSong catalog writer and scanner application.
- `CatalogReader`: read-only catalog and catalog-browser packages.
- `FrontendCore`: shared frontend commands, local-file browser, archive
  materialization/cache, archive playback adapter, preferences, queue, and
  playback-request infrastructure.

The projects remain siblings so local Swift package dependencies such as
`../VGMBoy`, `../CatalogReader`, and `../FrontendCore` stay explicit and
inspectable. Shared behavior belongs in a maintained package boundary; an app
must not copy another app's UI implementation to obtain it.

LaunchPad remains one level above this directory because it launches the whole
development workspace rather than belonging to the playback product family.

## What is included

VGMMan is a multi-frontend product family, not a single player binary. The
frontends share the same decoder registry, timing policy, archive materializer,
and catalog contracts while keeping their presentation and packaging separate.

| App or package | What it provides |
| --- | --- |
| **CocoaSpice** | Native macOS playlist, sidebar, queue, column, options, export, and playback UI. It links `VGMBoyKit` directly. |
| **SPCBoyWK** | The WebKit-based frontend with the same catalog, playback requests, settings contracts, Long Play controls, and decoder capabilities. |
| **SPCBoy** | The older Electron frontend retained for compatibility and historical comparison; it is not a second decoder implementation. |
| **ScanSong** | Scanner/catalog writer. It uses lightweight native readers and VGMBoy-built inspector executables, then writes the canonical SQLite catalog. |
| **VGMBoy** | Shared decoder, format routing, timing, Long Play, tempo, fade, EQ, audio output, and scanner-plugin build boundary. |
| **CatalogReader** | Read-only catalog models and queries shared by catalog consumers. |
| **FrontendCore** | Shared playback requests, archive/member materialization, local-file browsing, preferences, queue policy, and endpoint plumbing. |
| **LaunchPad** | Workspace launcher and build entry point, kept above this repository because it launches the whole development workspace. |

The intended data flow is:

```text
source files / archives
        │
        ▼
ScanSong ──writes──> Library.sqlite <──reads── CocoaSpice / SPCBoyWK / CatalogReader
        │                                      │
        └──uses VGMBoy inspector products   playback request + materialized member
                                               │
                                               ▼
                                           VGMBoyKit
```

There is one playback core. A frontend supplies a materialized playable path
and subtrack index; VGMBoyKit selects the decoder, renders audio, and reports
timing and natural-end state. It does not read or write the catalog or decide
which queue item plays next.

## Included decoder plugins

The current native plugin set is:

| Decoder or engine | Format families |
| --- | --- |
| **Game Music Emu / libgme** | AY, GBS, HES, KSS, NSF, NSFE, SAP, SPC |
| **libVGM** | VGM, VGZ, GYM, S98, DRO |
| **PSGPlay** | Atari ST SNDH, including declared subtunes |
| **mdxmini** | X68000 MDX and PDX dependency data, including the supported LZX 0.32/0.42 wrapper cases |
| **UADE** | Amiga EaglePlayer/replayer families, TFMX, MED, and prefix-led Amiga modules |
| **ZXTune AY-family bridge** | ASC, FTC, GTR, PSC, PSG, PSM, PT1/PT2/PT3, SQT, ST1/ST3/STC/STP, VTX, YM, and the admitted AS0 suffix |
| **vgmstream** | Console/game streamed audio, TXTP structures, and supported HD/HBD/IECS bank routes |
| **Highly Complete / mGBA + PSFLib** | GSF and miniGSF |
| **2SF / DeSmuME core** | 2SF and mini2SF |
| **Play! PSF core** | PSF, miniPSF, PSF2, miniPSF2 |
| **lazyusf2** | USF and miniUSF |
| **Audio Overload SDK** | QSF and miniQSF |
| **libsidplayfp** | SID |
| **libopenmpt** | MOD, XM, IT, S3M, and other registered tracker modules |
| **FFmpeg** | APE, MP2, and TAK |
| **Core Audio** | Ordinary finite macOS audio formats such as WAV, AIFF, FLAC, AAC, M4A, MP3, and CAF |

Source revisions, licenses, compatibility patches, and scanner handoffs are
tracked in [`VGMBoy/Docs/plugin-catalog.md`](VGMBoy/Docs/plugin-catalog.md),
[`VGMBoy/Docs/plugin-versions.json`](VGMBoy/Docs/plugin-versions.json), and
[`VGMBoy/vendor/PROVENANCE.md`](VGMBoy/vendor/PROVENANCE.md). The ZXTune bridge
is intentionally a focused AY-family build rather than the full desktop
application: `.ayl` remains unsupported because it is a separate wrapper
format, and `.ts` is not admitted until it has a qualified direct bridge and
fixture coverage.

## Special playback behavior

### Long Play

Long Play is a playback timing policy, not a file conversion and not a change
to the source stream. For loop-capable families it enables the decoder's loop
configuration and keeps the stream running; the audio clock continues at the
decoder's native rate. The ordinary end-time/default-duration setting controls
how the UI presents or bounds playback, while the source decoder remains
responsible for its own natural end and loop behavior. Formats with no natural
ending, such as USF and SID, are explicitly bounded by the shared timing
policy so they cannot run forever accidentally.

Natural-ending, Long Play, tempo, native-fade, and track-enumeration flags are
declared once in VGMBoy's format registry. Both native frontends consume that
capability projection; they must not recreate per-extension tables or impose
frontend-specific speed floors.

### Multi-track and dependency-aware formats

Subtracks are real decoder outputs. SNDH subtunes, libgme tracks, vgmstream
subsongs, UADE subsongs, and other enumerated structures become playlist rows
with a stable source path and track index. MDX PDX banks, PSF libraries,
mini-format libraries, TXTH files, and archive companions remain dependency
data and are not duplicated as tracks. ScanSong performs this materialization
before invoking the matching inspector, so playback and cataloging see the
same complete set.

### Metadata and database boundary

ScanSong is the sole catalog writer. Dumper, authored timing, track titles,
archive provenance, and decoder metadata are written once to the schema-23
catalog. CocoaSpice, SPCBoyWK, and CatalogReader share the read model; they do
not rescan, reinterpret, or maintain competing databases. Decoder metadata
that cannot be proven for a family remains empty rather than being synthesized
from a UI default.

## Build the family

From the repository root:

```bash
git submodule update --init --recursive
./VGMBoy/scripts/build-dependencies.sh
./VGMBoy/scripts/build-scanner-plugins.sh
swift test --package-path VGMBoy --disable-sandbox
swift test --package-path ScanSong --disable-sandbox
```

The app-specific build scripts package CocoaSpice, SPCBoyWK, or ScanSong after
the shared products are available. The scanner plugins are native VGMBoy
products, including `vgmboy-zxtune-inspect`; ScanSong does not link the entire
playback core merely to inspect a file. System dependencies are documented in
the VGMBoy plugin catalog and are intentionally kept separate from the shared
source and catalog contracts.

Working coordination documents:

- [`WIP-PLAN.md`](WIP-PLAN.md) — shared-core extraction plan.
- [`PARITY-WIP-REPORT.md`](PARITY-WIP-REPORT.md) — CS/SPCBoyWK behavioral parity ledger and next validation slices.

Decoder and scanner documentation:

- [`VGMBoy plugin catalog`](VGMBoy/Docs/plugin-catalog.md) — decoder pins, provenance, scanner products, dependencies, and format boundaries.
- [`ScanSong format accommodations`](ScanSong/ai/subsystem-agent/format-accommodations.md) — scanner-side routing, archive, sidecar, and multitrack behavior.
