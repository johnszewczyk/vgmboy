# UACMan Conversion Profiles

This directory is the canonical, editable source for UACMan conversion profiles. It documents source-format-to-UAC mappings and UAC packaging rules; VGMManDocs renders these Markdown files and saves edits back to this tree.
The UACMan GUI reads and edits `.uac` manifests only. The UACMan tool can use
MetaManCore during explicit package creation to read source formats. Apply the shared
[`BASE-UAC-PROFILE.md`](BASE-UAC-PROFILE.md); each format profile records only
its reader, field mapping, format-specific exceptions, and required checks.

These profiles are input rules for constructing and reviewing UAC packages;
they are not ROM-set inventory or completeness protocols. AudioMan owns
source-set membership, No-Intro matching, source-tree locations, and ROM/game
set reports. For each conversion, actual UAC tag coverage, package counts,
exceptions, and completed changes belong in AudioMan's per-set UAC dashboard.
Dated field evidence belongs in `UACMan/ai/reports/`; published profile
pages carry reusable format mappings. Do not use reports as duplicate status
for a live UAC set.

Platform identity uses one canonical package-level value. Apply the approved
names and source-label mappings in [`PLATFORMS.md`](PLATFORMS.md).

## Source-format ingest register

The reader IDs below are sourced from `MetaManCore.supportedFormats`. The
authoritative native-layout inventory is
[`MetaMan/format-layouts.md`](../../MetaMan/format-layouts.md). A reader being
supported does not by itself mean that a format-specific UAC projection has
been reviewed.

| MetaManCore reader ID | UAC profile status | Notes |
| --- | --- | --- |
| `ay` | Profile pending | AY subtune and timing behavior needs UAC mapping. |
| `sap` | Profile pending | SAP header directives, songs, and timings need UAC mapping. |
| `nsf` | Draft profile | See [`NSF-NSFE.md`](NSF-NSFE.md); fixture validation pending. |
| `gbs` | Draft profile | See [`GBS.md`](GBS.md); fixture validation pending. |
| `nsfe` | Draft profile | See [`NSF-NSFE.md`](NSF-NSFE.md); fixture validation pending. |
| `hes` | Draft profile | See [`HES.md`](HES.md); fixture validation pending. |
| `sndh` | Profile pending | Document subtune and timing projection. |
| `kss` | Draft profile | See [`KSS.md`](KSS.md); fixture validation pending. |
| `s98` | Profile pending | Document device table, tags, and timing fields. |
| `vgm` | Draft profile | See [`VGM.md`](VGM.md); fixture validation pending. |
| `mdx` | Profile pending | Document Shift-JIS title and PDX dependency. |
| `mod-protracker` | Profile pending | Document recognized MOD dialect boundaries. |
| `uac` | Wrapper profile | Container manifest reader; use the UAC wrapper contract, not a native-audio conversion profile. |
| `psf-family` | Profile pending | Document PSF, PSF2, SSF, USF, and 2SF tags and dependencies. |
| `gsf` | Profile pending | Document tags, PSFLib dependencies, and GBA header facts. |
| `qsf` | Profile pending | Document tags, QSound blocks, and QSFLib dependencies. |
| `spc` | Profile complete | See [`SPC.md`](SPC.md); live set coverage and tag outcomes are reported by AudioMan per set. |
| `sid` | Profile pending | Document PSID/RSID header and raw-header retention. |
| `ape` | Profile pending | Document APEv2/ID3 tags, seek table, and sample-count duration. |
| `adx` | Profile pending | Document ADX header and loop timing. |
| `aus` | Profile pending | Document Atomic Planet header and timing. |
| `at3` | Profile pending | Document RIFF chunks, INFO tags, and loop timing. |
| `msf` | Profile pending | Document Sony MSF variants and MPEG/frame timing. |
| `svag` | Profile pending | Document SVAG header and sample/loop facts. |
| `xmd` | Profile pending | Document XMD revisions and frame timing. |
| `sony-sshd` | Profile pending | Covers `.ads` and `.ss2`; document supported header variants. |
| `ps-headerless-mib` | Profile pending | Document headerless PlayStation MIB inference limits. |
| `bink-audio` | Profile pending | Document Bink audio header facts and stream scope. |
| `ngc-dtk-adp` | Profile pending | Document GameCube DTK ADPCM stream facts. |
| `txth-ima-adp` | Profile pending | Document TXTH-specified IMA ADPCM source requirements. |
| `ahx` | Profile pending | Document AHX header, version, and timing fields. |
| `dvi` | Profile pending | Document DVI/IMA block facts and timing. |
| `xa` | Profile complete | See [`PSX-CDXA.md`](PSX-CDXA.md); the PSX-specific workflow is also defined in the [protocol](../protocols/PSX-CDXA.protocol.md). |
| `nds-strm` | Profile pending | Document Nintendo DS STRM header and channel facts. |
| `nds-strm-ffta2` | Profile pending | Document the FFTA2-specific STRM extension. |
| `ngc-dsp-standard` | Profile pending | Document Nintendo DSP header and loop/sample fields. |
| `rs03` | Profile pending | Document RS03 metadata and supported member scope. |
| `ngc-thp-audio` | Profile pending | Document THP audio stream and timing fields. |
| `agsc` | Profile pending | Document AGSC header and sequence facts. |
| `genh` | Profile pending | Document GENH-derived fields and external configuration. |
| `standard-audio` | Profile pending | Document each supported codec and selected canonical-field projection. |

## Profile and report workflow

1. Copy [`FORMAT-PROFILE-TEMPLATE.md`](FORMAT-PROFILE-TEMPLATE.md) for a new
   reader profile and use its standard headings: Scope, Field Mapping, Format
   Procedures, and Required Checks. Write list entries as concise
   `- **Topic** — definition` lines. Keep reader facts linked to MetaManCore
   and wrapper contracts rather than repeating those contracts.
2. Before creating or rewriting a collection, check the register. MetaManCore
   reader support means a format can be inspected; it does not approve a UAC
   projection. Complete the field mapping and required fixture checks for that
   format first. Do not treat an unprofiled harvest as an approved conversion.
3. Record each reader fact's disposition in the format mapping table. Mark
   unknown or ambiguous values for review; use the base profile for shared
   tag, version, and hash rules.
4. Copy [`Sets/SET-PROFILE-TEMPLATE.md`](Sets/SET-PROFILE-TEMPLATE.md) for a
   new set profile. Use its standard headings and keep set-specific identity
   and provenance rules out of format field tables.
5. For each collection conversion, refresh the AudioMan per-set UAC dashboard
   with package/member counts, field coverage, diagnostics, identity/hash
   checks, review findings, and validation evidence. Do not put live-set
   output counts in an evergreen format procedure or duplicate them as a
   UACMan status report.
6. Promote a register row from pending only after its profile describes the
   complete reader-to-UAC mapping and has a verified collection report or
   an explicit format fixture report.

## Hash and timing scope

For compact, file-native, non-PCM music formats from the pre-disc era (including
SPC, VGM, NSF, NSFE, GBS, SID, AY/SAP, HES, KSS, and S98), create the normal
four playable-payload hashes for each physical source file: BLAKE3-256,
CRC32/ISO-HDLC, SHA-1, and MD5 under
`uac-playable-payload-v1`. This hashes the complete stored native file (or the
profile-defined normalized member, such as decompressed VGZ to VGM); it is not
a decoded-audio hash. Hash a file once even when it has many playlist entries
or subsongs. Keep the raw-member integrity records that UAC requires. Let the
UAC packer calculate missing member hashes while writing the wrapper; do not
rescan large files merely to duplicate those records in a report or database.

These four hashes are wrapper integrity/source-identity records, not music
tags. UACMan should expose them through its Stream Hashes view, not fabricated
tag keys such as `Stream CRC32`. For large PCM/disc-audio members, use the
standard wrapper integrity records and retain known source-image checksums as
source provenance; do not add a second decoded-PCM or per-track checksum
catalog without a specific preservation need.

Keep positive, authored playback timing when a supported consumer uses it.
Do not surface parser fallbacks or generic timing statistics as tags. Preserve
source playlist/timing data when it affects playback; a millisecond duration
is not a sample-accurate loop point. Record a loop only when positive,
source-backed data and the target player require it; never emit a negative
"no loop" marker.

## Shared field and ownership rules

Use the [UAC Base Profile](BASE-UAC-PROFILE.md) for direct-field mapping,
Title Case, omission, and platform-identity rules. `MetadataTag {name, value}` is
MetaManCore's reader interface, not a UAC tag format. Source provenance belongs
in `sources[]`; profile a direct metadata field only when it is useful to UAC
users.

## Set-Based Profiles

Set-specific profiles live in [`Sets/`](Sets/README.md). A format profile
describes reader-to-UAC behavior; a set profile records the source authority,
identity, naming, and review rules for that set. Never infer a
source relationship between collections from title or content overlap alone.

## Wrapper and ownership references

- UAC binary, manifest, and byte-preservation rules:
  [`ai/subsystem-agent/uac-wrapper-format.md`](../../../../../UACMan/ai/subsystem-agent/uac-wrapper-format.md)
- SPC native reader and field layout:
  [`MetaMan/format-layouts.md`](../../MetaMan/format-layouts.md)
- SPC-to-UAC profile: [`SPC.md`](SPC.md)
- Shared field-mapping rules: [`BASE-UAC-PROFILE.md`](BASE-UAC-PROFILE.md)
- Canonical platforms: [`PLATFORMS.md`](PLATFORMS.md)
- Compact pre-disc hash policy: [`PRE-DISC-NATIVE.md`](PRE-DISC-NATIVE.md)
- VGM/VGZ profile: [`VGM.md`](VGM.md)
- HES profile: [`HES.md`](HES.md)
- KSS profile: [`KSS.md`](KSS.md)
- NSF/NSFE profile: [`NSF-NSFE.md`](NSF-NSFE.md)
- GBS profile: [`GBS.md`](GBS.md)
- PlayStation CD-XA and Red Book profile: [`PSX-CDXA.md`](PSX-CDXA.md)
- Current PSX beta-package review:
  [`PSX-Beta-UAC-Review-2026-09-29.md`](../../../../../UACMan/ai/reports/PSX-Beta-UAC-Review-2026-09-29.md)
- Dated field and set audit:
  [`SNESMusicOrg-SPC-2026-09-23.md`](../../../../../UACMan/ai/reports/SNESMusicOrg-SPC-2026-09-23.md)
- Current SNESMusic.org tag-cleanup preview:
  [`SNESMusicOrg-SPC-Tag-Cleanup-Preview-2026-09-24.md`](../../../../../UACMan/ai/reports/SNESMusicOrg-SPC-Tag-Cleanup-Preview-2026-09-24.md)
- SNESMusic.org source-tag and Game ID surfacing preview and execution:
  [`SNESMusicOrg-Source-Tag-Surfacing-Preview-2026-09-24.md`](../../../../../UACMan/ai/reports/SNESMusicOrg-Source-Tag-Surfacing-Preview-2026-09-24.md),
  [`SNESMusicOrg-Source-Tag-Surfacing-Execution-2026-09-24.md`](../../../../../UACMan/ai/reports/SNESMusicOrg-Source-Tag-Surfacing-Execution-2026-09-24.md)
- Game ID assignment and Game Title review ledgers:
  [`SNESMusicOrg-Source-Tag-GameID-Preview-2026-09-24.tsv`](../../../../../UACMan/ai/reports/SNESMusicOrg-Source-Tag-GameID-Preview-2026-09-24.tsv),
  [`SNESMusicOrg-GameTitle-Review-Routing-Preview-2026-09-24.tsv`](../../../../../UACMan/ai/reports/SNESMusicOrg-GameTitle-Review-Routing-Preview-2026-09-24.tsv)
- OST Disc to Disc Number member ledger:
  [`SNESMusicOrg-Disc-Number-Preview-2026-09-24.tsv`](../../../../../UACMan/ai/reports/SNESMusicOrg-Disc-Number-Preview-2026-09-24.tsv)
- Album / Game Title discrepancy audit:
  [`SNESMusicOrg-Album-GameTitle-Discrepancy-2026-09-24.md`](../../../../../UACMan/ai/reports/SNESMusicOrg-Album-GameTitle-Discrepancy-2026-09-24.md)
- Package and member discrepancy ledger:
  [`SNESMusicOrg-GameTitle-Discrepancies-2026-09-24.tsv`](../../../../../UACMan/ai/reports/SNESMusicOrg-GameTitle-Discrepancies-2026-09-24.tsv)
