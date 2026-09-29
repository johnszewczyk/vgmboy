# Source format to UAC tag procedures

This directory documents how native metadata from source members is reviewed
and mapped into UAC tags. The UACMan GUI reads and edits tags in `.uac` files.
The UACMan tool can also use MetaManCore during package creation to read source
formats and map their metadata into a UAC manifest. Each profile records the
UAC fields retained, source data preserved outside that projection, provenance
and hash scopes, version handling, reader limitations, and required validation.
The source member bytes remain unchanged. Dated set audits belong in
`Reports/`; they record observations without changing the evergreen procedure.

A UAC has one manifest record. Tag names and values are direct fields in its
`game.metadata`, `variant.metadata`, `member.metadata`, or playlist entry fields;
there is no second tag store. New tag names use Title Case. Fixed structural
properties such as attachment references keep their contract spelling and are
not free-form tags.

System identity uses the single structural `game.console` field. Apply the
approved names and source-label mappings in
[`CANONICAL-SYSTEM-NAMES.md`](CANONICAL-SYSTEM-NAMES.md); do not duplicate a
system as `System`, `Platform`, `Console`, or `game.metadata.system`.

## Source-format ingest register

The reader IDs below are sourced from `MetaManCore.supportedFormats`. The
authoritative native-layout inventory is
[`MetaMan/FORMAT-LAYOUTS.md`](../../MetaMan/FORMAT-LAYOUTS.md). A reader being
supported does not by itself mean that a format-specific UAC projection has
been reviewed.

| MetaManCore reader ID | UAC procedure status | Notes |
| --- | --- | --- |
| `ay` | Profile pending | AY subtune and timing behavior needs UAC mapping. |
| `sap` | Profile pending | SAP header directives, songs, and timings need UAC mapping. |
| `nsf` | Draft profile | See [`NSF-NSFE.md`](NSF-NSFE.md); fixture validation pending. |
| `gbs` | Draft profile | See [`GBS.md`](GBS.md); fixture validation pending. |
| `nsfe` | Draft profile | See [`NSF-NSFE.md`](NSF-NSFE.md); fixture validation pending. |
| `hes` | Profile pending | Document bounded sidecar and track mapping. |
| `sndh` | Profile pending | Document subtune and timing projection. |
| `kss` | Profile pending | Document KSSX tracks and hardware facts. |
| `s98` | Profile pending | Document device table, tags, and timing fields. |
| `vgm` | Draft profile | See [`VGM.md`](VGM.md); fixture validation pending. |
| `mdx` | Profile pending | Document Shift-JIS title and PDX dependency. |
| `mod-protracker` | Profile pending | Document recognized MOD dialect boundaries. |
| `uac` | Wrapper profile | Container manifest reader; use the UAC wrapper contract, not a native-audio conversion profile. |
| `psf-family` | Profile pending | Document PSF, PSF2, SSF, USF, and 2SF tags and dependencies. |
| `gsf` | Profile pending | Document tags, PSFLib dependencies, and GBA header facts. |
| `qsf` | Profile pending | Document tags, QSound blocks, and QSFLib dependencies. |
| `spc` | Procedure complete | See [`SPC.md`](SPC.md) and the SNESMusic.org audit report. |
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
| `xa` | Procedure complete | See [`PSX-CDXA.md`](PSX-CDXA.md); the PSX-specific workflow is also defined in the [protocol](../protocols/PSX-CDXA.protocol.md). |
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
   reader profile. Keep reader implementation facts linked to MetaManCore and
   UAC wrapper contracts; do not duplicate those contracts as competing
   authorities.
2. Before creating or rewriting a collection, check the register. MetaManCore
   reader support means a format can be inspected; it does not approve a UAC
   projection. Complete the field mapping and required fixture checks for that
   format first. Do not treat an unprofiled harvest as an approved conversion.
3. State which source fields are decoded, which are projected to canonical
   UAC fields, which remain source-only, and which survive only in the
   byte-identical member. Mark unknown, ambiguous, and defaulted values
   explicitly.
4. Use **Format** as the one direct member tag for the contained source format.
   When the format defines a version, combine name and version in one value on
   every applicable member (for example, `SPC v.30` or `VGM v.1.71`), even
   when all members share it. Omit a version only when that format has none;
   never guess from an unreadable or malformed header. Report valid version
   variation and follow the format/set review rule while preserving each
   member's actual value. Do not duplicate it as Sub-Container Version, add a
   package version inventory, or use structural `member.format` as a visible
   tag; that field describes UAC's stored member encoding.
5. Specify package/source hashes separately from member/playable hashes,
   including the algorithm, scope, and profile. Keep package-level facts out
   of repeated track metadata.
6. For each collection conversion, write a dated report under `Reports/` with
   package/member counts, field coverage, diagnostics, version inventory,
   identity/hash checks, review findings, and validation evidence. Do not put
   collection-specific counts in an evergreen format procedure.
7. Promote a register row from pending only after its profile describes the
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

## Native tag projection rule

The `MetadataTag` `{name, value}` pair is MetaManCore's reader interface, not a
UAC tag or metadata schema. New harvests must not serialize a bulk copy of
native tags, parser diagnostics, or reader facts under `nativeMetadata` (or an
equivalent nested field). Keep the original member byte-for-byte and project
only populated, source-backed fields that are useful in the UAC manifest.
Store each selected field directly in ordinary UAC metadata using its
Title Case tag name, with the type and meaning defined by the format profile.
Put parser findings in the conversion report.

Project a source collection once as direct package tags **Set Collection**,
**Set Name**, and **Set URL**, with optional **Set Legacy URL**, **Set Archive
URL**, and **Set Date**. Keep matching source records in `sources[]` for
provenance; do not write a second nested `set` representation alongside these
tags. New recipe input using the former nested form is normalized to these
fields.

Each format profile must identify which source values become direct UAC
fields and which remain only in the unchanged member. Do not emit
`{"name":"body","value":"10"}` records or a second source-tag map. Use
Title Case for every tag name, including established names such as **Artist**,
**Album**, **Date**, and **Dumper**. Do not leak reader-side camelCase or
lowercase aliases into the tag map. Structural manifest properties are not
tags. Existing manifests with legacy `nativeMetadata` fields remain readable
and are not silently rewritten by readers.

## Source-set profiles

Set-specific provenance, identity, naming, and review rules live in
[`Sets/`](Sets/README.md). A format profile describes SPC-to-UAC behavior;
the set profile identifies source authority and release identity for one
collection. Never infer a source relationship between collections from title
or content overlap alone.

## Wrapper and ownership references

- UAC binary, manifest, and byte-preservation rules:
  [`ai/subsystem-agent/uac-wrapper-format.md`](../ai/subsystem-agent/uac-wrapper-format.md)
- SPC native reader and field layout:
  [`MetaMan/FORMAT-LAYOUTS.md`](../../MetaMan/FORMAT-LAYOUTS.md)
- SPC-to-UAC profile: [`SPC.md`](SPC.md)
- Canonical system names: [`CANONICAL-SYSTEM-NAMES.md`](CANONICAL-SYSTEM-NAMES.md)
- Compact pre-disc hash policy: [`PRE-DISC-NATIVE.md`](PRE-DISC-NATIVE.md)
- VGM/VGZ profile: [`VGM.md`](VGM.md)
- NSF/NSFE profile: [`NSF-NSFE.md`](NSF-NSFE.md)
- GBS profile: [`GBS.md`](GBS.md)
- PlayStation CD-XA and Red Book profile: [`PSX-CDXA.md`](PSX-CDXA.md)
- Dated field and set audit:
  [`Reports/SNESMusicOrg-SPC-2026-09-23.md`](Reports/SNESMusicOrg-SPC-2026-09-23.md)
- Current SNESMusic.org tag-cleanup preview:
  [`Reports/SNESMusicOrg-SPC-Tag-Cleanup-Preview-2026-09-24.md`](Reports/SNESMusicOrg-SPC-Tag-Cleanup-Preview-2026-09-24.md)
- SNESMusic.org source-tag and Game ID surfacing preview and execution:
  [`Reports/SNESMusicOrg-Source-Tag-Surfacing-Preview-2026-09-24.md`](Reports/SNESMusicOrg-Source-Tag-Surfacing-Preview-2026-09-24.md),
  [`Reports/SNESMusicOrg-Source-Tag-Surfacing-Execution-2026-09-24.md`](Reports/SNESMusicOrg-Source-Tag-Surfacing-Execution-2026-09-24.md)
- Game ID assignment and Game Title review ledgers:
  [`Reports/SNESMusicOrg-Source-Tag-GameID-Preview-2026-09-24.tsv`](Reports/SNESMusicOrg-Source-Tag-GameID-Preview-2026-09-24.tsv),
  [`Reports/SNESMusicOrg-GameTitle-Review-Routing-Preview-2026-09-24.tsv`](Reports/SNESMusicOrg-GameTitle-Review-Routing-Preview-2026-09-24.tsv)
- OST Disc to Disc Number member ledger:
  [`Reports/SNESMusicOrg-Disc-Number-Preview-2026-09-24.tsv`](Reports/SNESMusicOrg-Disc-Number-Preview-2026-09-24.tsv)
- Album / Game Title discrepancy audit:
  [`Reports/SNESMusicOrg-Album-GameTitle-Discrepancy-2026-09-24.md`](Reports/SNESMusicOrg-Album-GameTitle-Discrepancy-2026-09-24.md)
- Package and member discrepancy ledger:
  [`Reports/SNESMusicOrg-GameTitle-Discrepancies-2026-09-24.tsv`](Reports/SNESMusicOrg-GameTitle-Discrepancies-2026-09-24.tsv)
