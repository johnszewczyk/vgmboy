# UACMan Conversion Profiles

This directory is the canonical, editable source for UACMan conversion profiles. It documents source-format-to-UAC mappings and UAC packaging rules; VGMManDocs renders these Markdown files and saves edits back to this tree.
The UACMan GUI reads and edits `.uac` manifests only. The UACMan tool can use
MetaManCore during explicit package creation to read source formats. Apply the shared
[`BASE-UAC-PROFILE.md`](BASE-UAC-PROFILE.md); each format profile records only
its reader, field mapping, format-specific exceptions, application behavior,
and required checks. The base profile defines the shared UACMan, MetaMan,
ScanSong, Songbase, and dashboard contract; a format profile records only its
application-specific differences.

These profiles define source-format parsing and UAC metadata mappings; they are
not ROM-set inventory or completeness protocols. AudioMan owns source-set
membership, No-Intro matching, source-tree locations, and ROM/game set reports.
Existing UACs can be filtered and compared from their embedded metadata and
hashes without waiting for every reader profile to be complete. The profiles
are the subgoal for making new packages and richer metadata extraction
consistent across the major file types. Actual tag coverage and package
disposition belong in AudioMan's per-set reports. Dated field evidence belongs
in `UACMan/ai/reports/`; published profile pages carry reusable mappings.

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
| `ay` | Mapping documented; fixture review pending | See [AY/SAP/NSFE/SNDH/S98](AY-SAP-NSFE-SNDH-S98.md#ay). |
| `sap` | Mapping documented; fixture review pending | See [AY/SAP/NSFE/SNDH/S98](AY-SAP-NSFE-SNDH-S98.md#sap). |
| `nsf` | Mapping documented; fixture review pending | See [`NSF.md`](NSF.md); reader mappings are documented, while new package conversion still requires fixture and consumer review. |
| `gbs` | Reader/writer/consumer mappings aligned; package review pending | See [`GBS.md`](GBS.md); header identity stays at package scope; each logical track carries `Format`, source index, and approved title/order. M3Us remain byte-exact attachments; timing is not surfaced. Review a packaged fixture in UACMan, ScanSong, and Songbase before approving production conversion. |
| `nsfe` | Mapping documented; fixture review pending | Separate from NSF; see [NSFE profile](AY-SAP-NSFE-SNDH-S98.md#nsfe). |
| `hes` | Mapping documented; fixture review pending | See [HES.md](HES.md). |
| `sndh` | Mapping documented; fixture review pending | See [SNDH profile](AY-SAP-NSFE-SNDH-S98.md#sndh). |
| `kss` | Mapping documented; fixture review pending | See [KSS.md](KSS.md). |
| `s98` | Mapping documented; fixture review pending | See [S98 profile](AY-SAP-NSFE-SNDH-S98.md#s98). |
| `vgm` | Mapping documented; fixture review pending | See [VGM.md](VGM.md). |
| `mdx` | Mapping documented; fixture review pending | See [MDX and MOD](MDX-MOD.md). |
| `mod-protracker` | Mapping documented; fixture review pending | See [MDX and MOD](MDX-MOD.md). |
| `uac` | Wrapper profile | Container manifest reader; use the UAC wrapper contract, not a native-audio conversion profile. |
| `psf-family` | Shared mapping documented; extension review pending | See [PSF family](PSF-FAMILY.md) and [USF](USF.md). Existing USF fixture and scan evidence is recorded there; source-set conversion remains pending. |
| `gsf` | Mapping documented; fixture review pending | See [GSF profile](GSF.md). |
| `qsf` | Mapping documented; fixture review pending | See [QSF profile](QSF.md). |
| `spc` | Profile complete | See [`SPC.md`](SPC.md); live set coverage and tag outcomes are reported by AudioMan per set. |
| `sid` | Mapping documented; fixture review pending | See [SID profile](SID.md). |
| `ape` | Mapping documented; fixture review pending | See [APE profile](APE.md). |
| `adx` | Mapping documented; fixture review pending | See [console streams](CONSOLE-STREAMS.md). |
| `aus` | Mapping documented; fixture review pending | See [console streams](CONSOLE-STREAMS.md). |
| `at3` | Mapping documented; fixture review pending | See [console streams](CONSOLE-STREAMS.md). |
| `msf` | Mapping documented; fixture review pending | See [console streams](CONSOLE-STREAMS.md). |
| `svag` | Mapping documented; fixture review pending | See [console streams](CONSOLE-STREAMS.md). |
| `xmd` | Mapping documented; fixture review pending | See [console streams](CONSOLE-STREAMS.md). |
| `sony-sshd` | Mapping documented; fixture review pending | Includes `.ads` and `.ss2`; see [console streams](CONSOLE-STREAMS.md). |
| `ps-headerless-mib` | Mapping documented; fixture review pending | See [console streams](CONSOLE-STREAMS.md). |
| `bink-audio` | Mapping documented; fixture review pending | See [console streams](CONSOLE-STREAMS.md). |
| `ngc-dtk-adp` | Mapping documented; fixture review pending | See [Nintendo streams](NINTENDO-STREAMS.md). |
| `txth-ima-adp` | Mapping documented; fixture review pending | See [Nintendo streams](NINTENDO-STREAMS.md). |
| `ahx` | Mapping documented; fixture review pending | See [console streams](CONSOLE-STREAMS.md). |
| `dvi` | Mapping documented; fixture review pending | See [console streams](CONSOLE-STREAMS.md). |
| `xa` | Profile complete | See [`PSX-CDXA.md`](PSX-CDXA.md); the PSX-specific workflow is also defined in the [protocol](../protocols/PSX-CDXA.protocol.md). |
| `nds-strm` | Mapping documented; fixture review pending | See [Nintendo streams](NINTENDO-STREAMS.md). |
| `nds-strm-ffta2` | Mapping documented; fixture review pending | See [Nintendo streams](NINTENDO-STREAMS.md). |
| `ngc-dsp-standard` | Mapping documented; fixture review pending | See [Nintendo streams](NINTENDO-STREAMS.md). |
| `rs03` | Mapping documented; fixture review pending | See [Nintendo streams](NINTENDO-STREAMS.md). |
| `ngc-thp-audio` | Mapping documented; fixture review pending | See [Nintendo streams](NINTENDO-STREAMS.md). |
| `agsc` | Mapping documented; fixture review pending | See [Nintendo streams](NINTENDO-STREAMS.md). |
| `genh` | Mapping documented; fixture review pending | See [GENH profile](GENH.md). |
| `standard-audio` | Mapping documented; fixture review pending | See [standard audio profile](STANDARD-AUDIO.md). |

## Completion goal

Document the reader-to-UAC mapping for every major native game-audio reader in
`MetaManCore.supportedFormats`, including console-derived and standard
audio readers. A complete mapping states reader/version facts,
package/member/asset roles, field scope, dependency or playlist rules, and
preservation limits. Track fixture and package approval separately. Do not
claim a fixture or package is validated without recorded evidence. This
backlog does not block fast matching or metadata tagging of existing UACs.

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
6. Mark a profile mapping documented when it specifies the complete
   reader-to-UAC mapping. Track fixture and package approval independently;
   those checks are required before approving new conversions, not before
   tagging or comparing an existing UAC.

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

For No-Intro-backed identities, package **Game ID** is the canonical displayed
game-root title string. The numeric DAT `dat_id` is an internal join key held
by AudioMan's Museum reference-DAT catalog; do not copy it into UAC metadata or
structural canonical-ID arrays. The title root identifies the game, not a
region or revision. Set package **Region** to a supported territory or `--`
when the fast title/system filter leaves territory unknown. Keep `--` out of
filenames.

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
- NSF profile: [`NSF.md`](NSF.md); NSFE remains a separate pending profile.
- GBS profile: [`GBS.md`](GBS.md)
- PlayStation CD-XA and Red Book profile: [`PSX-CDXA.md`](PSX-CDXA.md)
- Current PSX beta-package review:
  [`PSX-Beta-UAC-Review-2026-09-29.md`](../../../../../UACMan/ai/reports/PSX-Beta-UAC-Review-2026-09-29.md)
- Dated field and set audit:
  [`SNESMusicOrg-SPC-2026-09-23.md`](../../../../../UACMan/ai/reports/SNESMusicOrg-SPC-2026-09-23.md)
- Current SNESMusic.org tag-cleanup preview:
  [`SNESMusicOrg-SPC-Tag-Cleanup-Preview-2026-09-24.md`](../../../../../UACMan/ai/reports/SNESMusicOrg-SPC-Tag-Cleanup-Preview-2026-09-24.md)
- Historical SNESMusic.org source-tag and numeric Game ID surfacing preview
  and execution (audit only; current Game ID values are canonical title roots):
  [`SNESMusicOrg-Source-Tag-Surfacing-Preview-2026-09-24.md`](../../../../../UACMan/ai/reports/SNESMusicOrg-Source-Tag-Surfacing-Preview-2026-09-24.md),
  [`SNESMusicOrg-Source-Tag-Surfacing-Execution-2026-09-24.md`](../../../../../UACMan/ai/reports/SNESMusicOrg-Source-Tag-Surfacing-Execution-2026-09-24.md)
- Historical numeric Game ID assignment and Game Title review ledgers (audit
  only; do not use numeric DAT IDs as UAC Game ID values):
  [`SNESMusicOrg-Source-Tag-GameID-Preview-2026-09-24.tsv`](../../../../../UACMan/ai/reports/SNESMusicOrg-Source-Tag-GameID-Preview-2026-09-24.tsv),
  [`SNESMusicOrg-GameTitle-Review-Routing-Preview-2026-09-24.tsv`](../../../../../UACMan/ai/reports/SNESMusicOrg-GameTitle-Review-Routing-Preview-2026-09-24.tsv)
- OST Disc to Disc Number member ledger:
  [`SNESMusicOrg-Disc-Number-Preview-2026-09-24.tsv`](../../../../../UACMan/ai/reports/SNESMusicOrg-Disc-Number-Preview-2026-09-24.tsv)
- Album / Game Title discrepancy audit:
  [`SNESMusicOrg-Album-GameTitle-Discrepancy-2026-09-24.md`](../../../../../UACMan/ai/reports/SNESMusicOrg-Album-GameTitle-Discrepancy-2026-09-24.md)
- Package and member discrepancy ledger:
  [`SNESMusicOrg-GameTitle-Discrepancies-2026-09-24.tsv`](../../../../../UACMan/ai/reports/SNESMusicOrg-GameTitle-Discrepancies-2026-09-24.tsv)
