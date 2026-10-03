# SNESMusic.org SPC-to-UAC field and set audit

- **Collection:** SNESMusic.org SPC Soundtrack Archive
- **Source URL:** <https://snesmusic.org/v2/torrent.php>
- **Audit date:** 2026-09-23
- **Format procedure:** [`../../../VGMManDocs/Docs/md/UACMan/Profiles/SPC.md`](../../../VGMManDocs/Docs/md/UACMan/Profiles/SPC.md)

## Corrected hash projection and database refresh

The original audit text below records the pre-correction manifest and Songbase
state. After that audit, each of the 1,519 current UACs was updated to carry
exactly four package-level **Source .rsn Hashes** (BLAKE3-256, CRC32, SHA-1,
and MD5). Each list item retains its byte size, scope (`source-rsn-file`), and
profile. The former Current/Initial source catalogs were removed from current
UAC source records. No `.rsn` was embedded; SPC and text payloads and per-track
four-item Stream Hash records were preserved.

The matching Songbase refresh indexed 6,076 source-RSN hash records and 1,520
Sub-Container Version groups for 1,519 packages. It removed 12,168 obsolete
Current/Initial source-hash rows from the active SNESMusicOrg hash index and
retired prior UAC object versions at the same active package paths. The final
active index has 6,076 source-file hashes and 139,668 stream-hash records
(exactly four for each of 34,917 SPC tracks). The source index has only the
`source-rsn-file` scope; SQLite foreign-key check and set-ledger validation
passed. Package hash details and the manifest rollback are in the linked
AudioMan batch directory. Temporary Songbase snapshots were deleted after
validation at the user's request; the cleanup is recorded in the set ledger.

## Inventory and integrity

The recursive UAC inventory contains 1,519 packages, 36,449 members, and
34,917 playable SPC files: 34,917 `.spc`, 1,530 `.txt`, and 2 `.htm` members.
No `.rsn` file is embedded in any UAC. The original `.rsn` packages remain
outside UAC as source-state. (The source-hash layout above supersedes the
pre-correction checksum description in the original audit.)

The 1,519 original RSN files now reside at
`/Users/john/Downloads/audio/SNESMusicOrg/<Source RSN>`. They were moved from
temporary staging by same-filesystem rename; file identities and sizes were
preserved, and the temporary RSN copies were removed. The relocation is recorded
in the SNESMusic.org set ledger.

Every SPC member has all four `uac-playable-payload-v1` hashes
(BLAKE3-256, CRC32/ISO-HDLC, SHA-1, and MD5), and every member has
`spcVersion`, `spcVersionByte`, and `spcHeaderVersion`. All 34,917 SPC records
contain ordered native tags, technical facts, diagnostics, raw ID666/xID6
block-byte counts, and a source-encoding value. No SPC was missing one of the
four playable hashes or three revision fields.

Two unsupported `playLengthMs: 150000` reader fallbacks were removed from the
UAC manifests. Both source ID666 `Length (seconds)` values were `0`, with no
positive xID6 intro, loop, or end duration. The exact SPC members, their native
tags, and compressed UAC payloads were preserved. The affected members are
`Wrecking Crew '98 (JP).uac` → `40-Open Door.spc` and `tetris dr mario.uac` →
`35-Dr. Mario Jingle 3.spc`.

## Decoded field coverage

All fields below are from the current manifest reader projection. Counts for
normalized member fields are SPC members with that field; native-tag counts
are occurrences and can include duplicate ID666/xID6 representations.

| Normalized member field | SPC members |
| --- | ---: |
| `title` | 34,917 |
| `spcVersion` | 34,917 |
| `spcVersionByte` | 34,917 |
| `spcHeaderVersion` | 34,917 |
| `introLengthMs` | 34,354 |
| `fadeLengthMs` | 25,016 |
| `playLengthMs` | 34,915 |
| `loopLengthMs` | 4 |
| `trackNumber` (explicit OST Track only) | 9,121 |
| `encodedBy` | 12,185 |
| `comment` | 8,983 |
| `artist` | 3,898 |
| `year` | 639 |
| `date` | 242 |

The complete normalized map and fields retained as source-only evidence are in
[`../../../VGMManDocs/Docs/md/UACMan/Profiles/SPC.md`](../../../VGMManDocs/Docs/md/UACMan/Profiles/SPC.md). Native tags preserved in member metadata include
Song, Game, Dumper, Comment, Date, Length (seconds), Fade (milliseconds),
Artist, Copyright Year, Publisher, Intro/Loop/End/Fade Length, OST Title, OST
Disc, OST Track, Loop Count, Muted Voices, and other recognized tags. Repeated
tag entries stay ordered. The SPC payload itself preserves raw bytes, unknown
xID6 IDs and values, original encoding, duplicate values, reserved bytes,
CPU/DSP state, and RAM; these are not all separate normalized manifest fields.

| Recognized native tag | Occurrences |
| --- | ---: |
| Artist | 41,332 |
| Game | 37,069 |
| Dumper | 35,495 |
| Song | 35,324 |
| Length (seconds) | 34,917 |
| Fade (milliseconds) | 34,917 |
| Copyright Year | 34,324 |
| Publisher | 34,484 |
| Intro Length (ms) | 34,354 |
| Fade Length (ms) | 24,222 |
| Comment | 10,253 |
| OST Track | 9,121 |
| Loop Count | 4,311 |
| OST Title | 3,129 |
| OST Disc | 2,474 |
| Date | 585 |
| Muted Voices | 92 |
| Loop Length (ms) | 4 |
| End Length (ms) | 2 |

## Header, version, and parser findings

No SPC signature/header was rejected as invalid. Header text says `0.30` for
all 34,917 SPC files. The SPC revision byte yields `0.30` for 34,916 files and
`0.10` for one file. Exactly one package contains multiple byte-derived SPC
revisions: `RPG Maker 2.uac` contains 39 revision-`0.30` members and one
revision-`0.10` member. The older member `19-Frozen Wasteland.spc` has a textual
header version of `0.30` and a revision byte of `10` (`spcVersion` `0.10`).

That package is now at
`Review/Mixed SPC Versions/Nintendo SNES/RPG Maker 2.uac`. The AudioMan set
ledger records `mixed-sub-container-version` as a critical set-level finding.
The UAC manifest keeps its version inventory and does not receive an invented
`criticalFlags` field.

MetaManCore emitted 373 xID6 diagnostics across the inventory:

| xID6 diagnostic | Members |
| --- | ---: |
| Signature present but chunk header or declared payload truncated | 4 |
| Item payload exceeds its chunk boundary | 286 |
| Incomplete non-padding item at end of chunk | 83 |

These are malformed optional xID6 metadata regions, not invalid SPC signatures.
They are retained as per-member diagnostics, and the original SPC bytes remain
unchanged so all affected structures can be inspected or reparsed. They are
not silently promoted to canonical tags.

## Database and provenance interpretation

The set reindex includes the review-folder package recursively. The existing
canonical title link for RPG Maker 2 is retained and moved to its new package
path. The parent `.rsn` is not a UAC member: the manifest links to it by source
identity and one four-hash catalog. Those checksums establish byte identity
for the recorded source file, not a directional historical relationship
between SNESMusic.org, JoshW, VGMRIPS, or another aggregator.

An exact cross-set hash match can show that two catalogs contain the same
bytes. It cannot by itself establish which site copied from which, which set
was complete first, or whether either was an independent distribution. Keep
each collection as separate source evidence unless dated inventories,
contemporaneous documentation, or explicit provider records establish more.
JoshW filename-harvest values have not yet been overlaid on these packages;
apply them only after this source inventory is accepted, with per-value
provenance and confidence retained.

## Additional SNES metadata recommendations

- Add region and a canonical release/catalog ID only when supported by
  positive source evidence. Preserve the citation/source and any disagreement
  alongside the value; do not infer region from an ambiguous filename.
- Retain explicit game release date/year separately from SPC Copyright Year.
  Do not turn Copyright Year into a release date.
- Keep Publisher as source evidence until a canonical publisher field and its
  meaning are agreed. Do not guess developer/publisher from company codes.
- Consider typed soundtrack fields for OST Title/Disc and exact player
  controls such as muted voices, mixing level, loop count, and end length.
  Keep them namespaced/source-specific until the shared UAC vocabulary defines
  stable semantics; never relabel soundtrack title as a game Album.
- Preserve explicit soundtrack track numbers and the existing ordered
  playlist. Do not derive numbers from file order or rename source tracks based
  on a fuzzy filename match.
- Keep exactly one four-hash parent `.rsn` catalog at package metadata and
  four per-SPC playable hashes on each track. Do not retain the obsolete
  Current/Initial source-hash catalogs.

## Validation record

- The prior restage checkpoint verified all 1,519 package payloads and
  36,449 members. This pass changed two manifests only and moved one package;
  the modified wrappers retain their original payload BLAKE3 values.
- Reindex scope: 1,519 packages, 36,449 members, 34,917 playable members,
  71,366 CRC records, 12,152 parent-source checksum records, and 1,520
  contained-version groups.
- Songbase has 1,519 current UAC package paths, no inventory row for the
  prior RPG Maker 2 path, one current review-path row, and the retained
  high-confidence canonical title link at that new path. `PRAGMA
  foreign_key_check` returned no rows.
- The exact package move, manifest diffs, backup paths, database state, and
  critical finding are recorded in the SNESMusic.org AudioMan set ledger.
