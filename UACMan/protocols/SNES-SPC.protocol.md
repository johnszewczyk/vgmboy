# SNESMusic.org SPC protocol

This protocol defines the metadata and integrity profile for byte-preserving
SNESMusic.org SPC packages. It complements the shared UAC manifest contract
in `../ai/subsystem-agent/uac-wrapper-format.md` and AudioMan's source-set
workflow.

## Canonical tag vocabulary

UAC stores canonical field keys and types; human-facing views use the sentence-
case labels below. Do not serialize a second copy merely to capitalize a key.

| Display label | Canonical location | Rule |
| --- | --- | --- |
| Game ID | `game.id` | Use the stable AudioMan logical game identity. Keep external positive release IDs in `game.canonicalIDs`; do not invent IDs to fill a gap. |
| Game Title | `game.title` | One canonical package title. Preserve differing embedded SPC game titles in source-tag evidence and report disagreement; do not repeat the title on every track. |
| Game Region | `game.metadata.region` | Include only when source or positive release-ID evidence establishes one region. Omit when unknown; use explicit variants when the package contains distinct regional releases. |
| System | `game.console` | Canonical value `Nintendo SNES`; do not repeat source synonyms such as `Super Nintendo` on each track. |
| Set | `game.metadata.set` | One source-backed object: `{ "collection": "SNESMusicOrg", "name": "Nintendo SNES", "url": "https://www.snesmusic.org/v2/" }`. |
| Track Title | `member.metadata.title` | Project the SPC Song field when nonempty. |
| Artist | `member.metadata.artist` | Project the source Artist field when present. |
| Album | `member.metadata.album` | Project an explicit soundtrack/album field only; do not copy Game Title into Album. |
| Year | `member.metadata.year` | Preserve an explicit year. Do not derive a second Year value when the same source already provides a full Date. |
| Date | `member.metadata.date` | Preserve a source date when present. Keep ambiguous or unparsable source text in source-tag evidence rather than guessing. |
| Genre | `member.metadata.genre` | Include only when explicitly present. |
| Comment | `member.metadata.comment` | Preserve a nonempty source comment. |
| Encoded By | `member.metadata.encodedBy` | Project the SPC Dumper field when present. |
| Track Number | `member.metadata.trackNumber` | Include only for an explicit source track number/OST Track value. Never number tracks from file order. |
| Game Version | `member.metadata.gameVersion` | Record a track-specific game revision only when source evidence identifies it. If all tracks share one proven revision, the package may also expose `game.metadata.gameVersion`; do not invent a revision or write an empty placeholder. |
| SPC Version | `member.metadata.spcVersion` | Store the parsed per-file SPC format revision. Keep byte/header details as technical evidence and report parser disagreement. |
| Checksums | projection of `member.hashes[]` | Display the four playable-payload hashes as one per-track checksum list. Do not duplicate them in `member.metadata.checksums`. |

Only populated source values become tags. Positive measured SPC timing fields
may be retained; zero or unavailable intro, loop, play, and fade values are
omitted. A millisecond timing value is not a sample-accurate loop point.

## Source-tag preservation

Copy each original SPC member byte-for-byte. This retains ID666 and xID6 data,
including original names, encoding, duplicates, unknown fields, and raw tag
bytes. MetaMan's ordered `nativeMetadata.tags` projection may be retained as a
source-evidence group; it is not a second user-facing tag set. Present that
group as **Source Tags** with name/value entries rather than as an opaque
`tags` field or `[Object • #]` summary. Do not repeat archive names, source
URLs, or source archive hashes in per-track metadata; those belong in
`sources[]` and the package-level `setCollection`, `setName`, and `setUrl`
fields.

Map recognized source values to the canonical fields above. Leave unknown
source fields in the source-evidence group and keep their source member bytes
unchanged. Do not create aliases such as `gameTitle` beside `game.title`,
`trackTitle` beside `member.metadata.title`, `dumper` beside `encodedBy`, or
`system` beside `game.console`.

## Four-hash stream profile

Every playable SPC member has four hashes for its exact playable-payload byte
scope, using profile `uac-playable-payload-v1`:

1. `blake3-256`
2. `crc32-iso-hdlc`
3. `sha1`
4. `md5`

For SPC, this profile hashes the complete stored `.spc` file bytes, including
its SPC header and embedded tag data. It is not an emulator-rendered audio
hash. The BLAKE3 digest must equal both `member.blake3` and `streamBlake3` for
an unchanged SPC member. Keep the existing separately scoped raw-member CRC
record required by the wrapper; the playable-payload records are what the
Checksums list displays. Use eight uppercase hexadecimal digits for CRC32 and
lowercase hexadecimal for BLAKE3, SHA-1, and MD5.

Reuse stored BLAKE3 and CRC32 values only after exact member bytes and hash
scope/profile match. Compute missing SHA-1 and MD5 over those same bytes. A
source-reported checksum is separate evidence: retain it with its origin and
scope, and do not substitute it for a locally verified hash. Hash equality
establishes byte identity only, not correct game identity, completeness, or
absence of a valid alternate version.

## Version and set-quality audit

Record the parsed version on every SPC member and aggregate version counts in
`game.metadata.containedContainerVersions`. Report a package as mixed-version
when its playable SPC members contain more than one version or when a member's
header representations disagree. Do not rewrite, normalize, or silently discard
a version based on that report.

Before packaging, test each source `.rsn`, enumerate its complete contents,
and audit every extracted member. Report unreadable archives, failed member
CRC/integrity checks, malformed or truncated SPC files, duplicate paths,
unsupported payloads, metadata parser diagnostics, duplicate streams, and
cross-title or cross-version content matches. Preserve unresolved cases for
review; do not use a title or hash match alone as deletion authority.

Exclude AppleDouble `._*` files, `.DS_Store`, `__MACOSX/`, and `.AppleDouble/`
from staged UAC payloads. Count and report excluded sidecars separately. Keep
the original `.rsn` source packages in source-state; a derived UAC does not
replace them.

## Package provenance and Songbase

Record collection, set name, exact source URL, source archive name/path, and
source archive BLAKE3 once at package/source level. Per-track members retain
their original member names, normalized tags, SPC version, and stream hashes.
The ordered playlist points to the playable member paths and preserves an
original playlist when present; it does not manufacture track numbers.

After UAC payload and four-hash verification, ingest package/member hash,
tag, source, and version evidence into Songbase. Reconcile existing
SNESMusic.org records by exact BLAKE3/profile first; reuse existing matching
values and compute only missing algorithms. Keep canonical game identity and
region evidence in their database fields as well as the package fields when
known. Do not retire source-state material as part of this workflow.

## Required validation

1. Confirm the staging manifest excludes sidecars and accounts for every
   source archive and extracted member.
2. Test all `.rsn` archives and validate extracted SPC headers, tag diagnostics,
   and contained versions.
3. Require one verified BLAKE3, CRC32, SHA-1, and MD5 record per playable SPC
   stream at the declared playable-payload scope/profile.
4. Run `uacman inspect --verify` and a complete unpack/readback check; compare
   every output member path, byte count, and BLAKE3 with the staging manifest.
5. Back up Songbase before applying the package index and verify the resulting
   member/hash/version counts.
