# Project Info

## Product

`ScanSong` is the independent Swift package and native scanner app. `ScanSongKit` owns
discovery, inspection, archive handling, schema-23 catalog creation, resumable staging, and
publication. The product is the sole catalog writer consumed by CocoaSpice and SPCBoy.

## Major Components

- `ScanSongKit` — host-independent scanning and catalog engine.
- ScanSong's intended role is orchestration: source discovery, safe file and
  archive handling, metadata-reader routing, and catalog publication. Complete
  format interpretation belongs in MetaMan; scanner UI/CLI and database
  ownership stay here.
- `MetaManCore` — shared decoder-independent metadata reading for AY, SAP,
  NSF/GBS/NSFE, HES/M3U, APE, ADX, AUS,
  RIFF ATRAC3/ATRAC3+, Sony MSF, Konami/SNK SVAG and XMD, Nintendo DSP/RS03/THP, Sony XA, SID PSID/RSID,
  SPC ID666/xID6, S98, VGM/VGZ, and PSF/PSF2/SSF/USF/2SF tag footers. ScanSong maps neutral
  ordered track documents to schema 23. All complete direct format readers
  listed here are owned by MetaMan; ScanSong retains routing, safe source and
  archive handling, dependency preparation, and schema-23 projection.
- `scansong` — versioned JSONL command-line boundary.
- `ScanSong` — native catalog-management interface.
- `build-app.sh` and `launch.sh` — fresh packaging and launch boundary.

APE (`.ape`) is a supported single-track route. MetaMan reads its container
timing and native tags in-process; ScanSong adapts the neutral document and
does not link VGMBoyKit, invoke a decoder, or transcode the source. VGMBoy
retains FFmpeg for playback.
GSF/miniGSF use MetaManCore's complete PSF v0x22 reader for container/CRC/zlib
validation, GBA segment stitching, PSFLib resolution, ordered tags, and
authored timing. QSF/miniQSF use MetaManCore's complete PSF v0x41, QSound-block,
tag/timing, and direct QSFLib-validation reader.
Neither route starts mGBA/Highly Complete or the QSound playback core. Those
cores remain in VGMBoy for playback. Scanner inspectors use VGMBoy's narrow inspection target;
scanner-plugin preparation does not invoke the broad playback dependency
builder or prepare mGBA/QSF as scanner build-time collateral.
CRI/Monster ADX headers and native loop timing are read through MetaManCore;
the vgmstream helper remains for other streams and non-ADX payloads that reuse
`.adx` (including Ogg and RIFF).
Sony CD-XA sectors and interleaved subsongs are read completely by MetaManCore;
ScanSong retains only content-aware routing and catalog projection. Unrelated
formats using `.xa` remain on the vgmstream route.
Atomic Planet AUS headers are read by MetaManCore, which preserves the exact
32-byte header and native codec/sample/channel/loop facts while projecting
the prior timing. Non-AUS payloads with the `.aus` suffix retain the vgmstream
route; playback still uses VGMBoy's decoder path.
RIFF ATRAC3/ATRAC3+ metadata is read by MetaManCore, including ordered
`LIST/INFO` tags, native `fact`/loop timing, and retained non-audio RIFF chunks.
Nonmatching `.at3` aliases retain the vgmstream route; playback stays in
VGMBoy.
Recognized Sony MSF headers are read by MetaManCore, including codec-based
sample/loop timing, stream names, and retained source facts; `MSF ` and other
non-Sony aliases remain on the vgmstream route. VGMBoy keeps the playback path.
Known Konami and SNK SVAG headers are read through MetaManCore, with unrelated
`.svag` signatures retaining the vgmstream route.

## Task Routing

- Scanner ownership and protocol: [scanner-contract.md](/Users/john/Downloads/Code/VGMMan/ScanSong/ai/subsystem-agent/scanner-contract.md)
- Per-plugin intake behavior: [format-accommodations.md](/Users/john/Downloads/Code/VGMMan/ScanSong/ai/subsystem-agent/format-accommodations.md)
- Build and plugin packaging: [build-integration.md](/Users/john/Downloads/Code/VGMMan/ScanSong/ai/subsystem-agent/build-integration.md)
- UAC manifest-only catalog boundary: [player-integration.md](/Users/john/Downloads/Code/VGMMan/UACMan/ai/subsystem-agent/player-integration.md)
- Command-line behavior: [cli.md](/Users/john/Downloads/Code/VGMMan/ScanSong/ai/subsystem-human/cli.md)
- Native catalog management: [catalog-management.md](/Users/john/Downloads/Code/VGMMan/ScanSong/ai/subsystem-human/catalog-management.md)

## Local Rules

- ScanSong is the sole schema-23 catalog writer.
- For `.uac`, project catalog fields from the manifest only; do not parse
  enclosed native tags as an automatic fallback.
- Player apps read the catalog; they do not receive scanner write access.
- ScanSong receives inspection executables from VGMBoy and never invokes a player frontend.
- Human notes describe implemented UI behavior; agent notes describe scanner ownership and failure boundaries.

## File-type policy and unsupported formats

ScanSong's Options window exposes the scanner's persisted **File Types** policy.
Checked extensions are skipped before discovery or archive-member routing. This
list is intentionally limited to families for which the current bundled
decoder set has no implementable scanner route:

| Extension | Family | Current status |
| --- | --- | --- |
| `.sgc` | Sega Game Gear / SGC | No established decoder in VGMBoy or the scanner. Do not route through vgmstream. |
| `.ncsf`, `.minincsf`, `.ncsflib` | Nintendo DS NCSF | Dependency-based Nintendo DS sound format has no usable decoder adapter. |
| `.mus` | Doom MUS | The Doom MUS members examined here are rejected by the bundled vgmstream path; no scanner decoder is available. |
| `.m3u` | Playlist wrapper | A playlist is not itself a playable scanner source; the referenced files are scanned independently. |

The default policy ignores those extensions and can be changed from Options so
future decoder work can be tested without changing catalog code. This is not a
generic error suppressor: supported families remain inspectable. For example,
`.ss2` is a supported vgmstream route, so a malformed Silent Hill PS2 member is
reported as an archive-member failure instead of being hidden.

The following previously failing vgmstream routes are now wired through the
scanner's bundled inspector: `.strm`, `.ahx`, `.bik`, `.bika`, `.xmd`, `.txtp`,
and `.hd`/`.hbd`/`.iecs`. TXTP dependency aliases are materialized
inside the extracted archive before inspection, including underscore-prefixed
TXTH aliases such as `_.ldat.txth`. Archive inspection keeps valid
members when another member fails, and records the failed member in the scan
inventory and result log. Archive members with genuinely unknown extensions are
retained as grouped `unrecognized` diagnostics; known decoder sidecars and
archive documentation remain quiet. Archive extraction is serialized to one
payload at a time, TAR.ZST uses a streaming `zstd -dc` to `tar` pipeline rather
than a second full temporary TAR, and stale scratch roots older than one day
are removed when extraction starts. Disposable scratch prefixes are removed
from failure messages before catalog persistence as well as log rendering.

## Current failure boundary

The latest JohnS report confirms these are different cases and must not be
collapsed into one ignored-format bucket:

- Game Boy `.gbs` in the Bakukyuu Renpatsu archive is rejected by the selected
  emulator route (`Wrong file type for this emulator`). It remains a decoder
  integration gap until the correct VGMBoy/Game Boy sound route is proven.
- SPC metadata is harvested in-process by MetaManCore from text/binary ID666
  headers and optional xID6 chunks; dump date, dumper, emulator, soundtrack, and
  native timing facts remain available in the shared document. The ScanSong
  projection retains the established catalog values, including the 150-second
  default for valid tagless files. Production targets do not link or invoke
  libgme for SPC inspection; VGMBoy keeps libgme for playback.
- MetaManCore reads PSF-style `[TAG]` footers and authored length/fade hints
  for PSF/PSF2, SSF, USF, and 2SF without starting their playback plugins.
  GSF/miniGSF use MetaManCore's complete PSF v0x22/container reader, including
  compressed payload validation, GBA segment stitching, and the dependency
  chain; mGBA remains playback-only. QSF/miniQSF use MetaManCore's PSF v0x41
  container and QSound block reader, validating declared QSFLib dependencies
  and extracting tags/timing without playback code.
  NSF/GBS use a
  dependency-free header route for enumeration and native text metadata; their
  formats do not contain authored per-track names or timing, so the reader
  preserves libgme's unknown intro/loop/fade values and 150-second default
  play-length policy without starting playback. NSFE uses the matching
  dependency-free chunk route, including playlist, labels, authors, and
  authored time/fade values.
- VGM and gzip-compressed VGZ GD3/timing data are read through `MetaManCore`;
  GD3 release date, converter, notes, both language variants, and original tag
  bytes are exposed. VGZ expansion is bounded in MetaManCore. ScanSong preserves
  its existing notes-only comment projection. S98 v0-v3 header, device, tag,
  and command timing are also read through `MetaManCore`, with the full ordered
  tag set and original block preserved. A v3 `DATE` is exposed independently
  from `YEAR`; direct timing uses the actual header loop offset for intro
  duration. A test-only libvgm oracle records these known improvements
  separately from regressions.
  GYM remains a legacy structure-known libVGM route without scanner metadata;
  it is not a MetaMan migration target.
- HES inspection passes the source and bounded same-basename sibling `.m3u`
  context to MetaMan. The playlist is not catalogued as a track itself; it maps
  raw HES address slots to authored music/SFX tracks and timing. Without it,
  the ordered 256-slot compatibility listing remains, with the legacy zero-time
  catalog projection.
- SAP inspection consumes MetaManCore's ordered per-track header documents for
  subsong count, all directives, identity, and native `TIME` hints; finite
  times become play lengths and `LOOP` times become intro-to-loop positions.
  SAP no longer uses libgme in ScanSong. AY inspection also consumes
  MetaManCore's ordered per-track
  result, preserving signed relative-pointer metadata, native subtune ordering,
  and per-track 50 Hz lengths. The fixture-gated AY parity test covers the
  Project AY archive's 1,175 files, but requires `SCANSONG_AY_FIXTURE_DIR`;
  that corpus run was not available during the MetaMan cutover verification.
  The earlier SAP corpus comparison covered all 6,335 local ASMA files using
  the former direct reader; the current parity test is fixture-gated by
  `SCANSONG_SAP_FIXTURE_DIR`. No SAP rows were present in the inspected
  CocoaSpice catalog.
- Silent Hill: Shattered Memories `.ss2` members fail to open. `.ss2` is an
  established route, so these remain visible archive-member failures and are
  not ignored.
- Silent Hill HD Collection `.hd` members fail to open through the current
  `.hd`/`.hbd`/`.iecs` adapter. The archive contains IECS `.hd` indexes with
  `.td` control data and separate Sony `.msf` ATRAC streams. The direct MSF
  reader opens those streams, but vgmstream's `hd_bd` reader expects a standard
  `.hd` plus `.bd` layout (or a combined `.hbd`). The `.hd` files therefore
  remain a format-adapter gap rather than evidence that the audio is corrupt;
  keep their failures visible until the matching IECS/`.td` adapter is added.

The last-result scan log uses uniform `status | detail | path` columns. Paths
are relative to the selected scanner root, including the `archive#member`
identifier for an archive error. Redundant member names are removed from the
detail column. Successful archive members are never listed; skipped archive
members are grouped by archive and extension. Unknown archive members use
`unrecognized` rows without becoming catalog candidates, while known support
files and extensionless archive material remain quiet.
Scan, Check Links, and Remove Links share one operation telemetry model in the
native UI: item progress, failure/missing counts, elapsed `HH:MM`/`HH:MM:SS`,
and completion time are reported uniformly.
The CLI progress stream is rate-limited to phase changes, phase completion, or
at most one progress event per second so diagnostics cannot become the scan's
throughput limiter.

## Human Docs

- `ai/subsystem-human/` contains the current catalog-management and command-line behavior notes.
- `README.md` contains the user-facing build and scanner overview.
