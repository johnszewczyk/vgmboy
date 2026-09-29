# SPC to UAC procedure and field profile

This procedure defines the reusable metadata, provenance, integrity, naming,
and review steps for SPC members packaged in UAC. MetaManCore is the native
reader; UACMan applies the SPC projection and preserves source members. The
SNESMusic.org set details below are the reference case, not assumptions about
other SPC collections.

## Reader coverage

MetaManCore reads SPC ID666 and xID6 directly; it does not start an emulator.
The reader recognizes these source fields:

| Source block | Recognized values |
| --- | --- |
| ID666 fixed slots | Song, Game, Dumper, Comment, Date, Length (seconds), Fade (milliseconds), Artist; text or binary layouts; emulator code and muted-voice byte facts. |
| xID6 | Song, Game, Artist, Dumper, Date, Emulator, Comment, OST Title, OST Disc, OST Track, Publisher, Copyright Year, Intro Length, Loop Length, End Length, Fade Length, Muted Voices, Loop Count, Mixing Level. |
| SPC header | Signature text version, revision byte, ID666 flag/layout, and parser facts are audited in the conversion report; keep raw header bytes in the SPC member. |

When both ID666 and xID6 supply a field, the reader chooses the projection
value according to MetaManCore's precedence; the byte-identical SPC remains
the authoritative source for duplicates, unknown xID6 items, reserved bytes,
CPU/DSP state, RAM, and all raw ID666/xID6 bytes. Do not serialize a generic
**Native Metadata** field into ordinary member metadata. Put required parser
findings in the dated conversion report; do not rewrite source tags.

## Canonical projection and source-only fields

The shared fields below are the searchable UAC projection. Empty or default
values are not source evidence.

| SPC value | UAC location | Rule |
| --- | --- | --- |
| Package Game ID | `game.metadata["Game ID"]` | Add the four-digit No-Intro DAT ID as a package-level tag only for a unique, high-confidence Nintendo SNES match. Keep it separate from package `game.title`, track Game Title, Album, and OST Title until reconciliation. |
| System | `game.console` | Use the canonical system once at package level. |
| Title | `member.metadata["Title"]` | Project the populated Song value. |
| Album, Game Title, OST Title | `member.metadata["Album"]`, `member.metadata["Game Title"]`, `member.metadata["OST Title"]` | Preserve source fields separately. Do not create Album by relabeling OST Title or replace Game Title with package `game.title`. Keep lists and per-track variation intact; route such packages to the Game Title review folder. |
| Disc Number, OST Track | `member.metadata["Disc Number"]`, `member.metadata["OST Track"]` | Map source OST Disc to Disc Number, preserving its value. Keep OST Track under its source name; do not reinterpret it as display order. |
| Artist, Date, Year, Comment, Dumper, Publisher | Direct Title Case `member.metadata` tags | Copyright Year maps to Year; source bytes are not edited. Do not move values to package scope merely because they are unanimous. |
| Track Number | Display projection from canonical member path | Use the zero-padded path prefix for display order, such as `00`, not a decoded OST Track field whose source encoding may not be a sequence number. Preserve a populated source OST Track separately. |
| Format | `member.metadata["Format"]` | Record the actual SPC version as one value (for example, `SPC v.30`) on every member, even when uniform. Do not infer a value from a missing or malformed header. Valid variation is normal member metadata; a mixed-version package follows the set-level review rule below while retaining every member's Format. |
| Positive timing | `member.metadata["Intro Length (ms)"]`, `["Loop Length (ms)"]`, `["Play Length (ms)"]`, `["Fade Length (ms)"]` | Retain only positive source-backed timing. Omit a reader fallback duration when no native duration exists. |
| SPC reader diagnostics | Conversion audit report | Do not serialize an opaque **Native Metadata** field. Preserve the byte-identical SPC source; record relevant parser diagnostics in the report. Do not rewrite ID666/xID6 tags. |
| Four playable hashes | `member.hashes[]` and track checksum view | Use `uac-playable-payload-v1` for BLAKE3-256, CRC32/ISO-HDLC, SHA-1, and MD5 over the complete stored SPC bytes. Display a nested checksum list with labels such as Stream BLAKE3-256, Stream CRC32, Stream SHA-1, and Stream MD5. |

For SNESMusic.org, retain populated **OST Title** and **OST Track** under their
source names, and map source **OST Disc** to **Disc Number** while preserving
its value. Do not map OST Title to Album or OST Track to display order. End
Length, Loop Count, Muted Voices, Mixing Level, and Emulator remain in the
byte-identical SPC source and conversion evidence unless a set-specific rule
explicitly surfaces them. Do not infer Album from OST Title or infer
publisher/developer from company names.

MetaMan's SPC reader supplies a 150,000 ms fallback when no source duration is
available. That fallback is not measured SPC metadata: omit
`Play Length (ms)` unless ID666 Length is positive or positive xID6 intro, loop,
or end duration supports the value. Keep the raw source values and the reader
diagnostic facts either way.

## Reusable conversion steps

1. Treat each `.rsn` as an outer source package. Test it and enumerate every
   member before packaging. The source `.rsn` itself stays in source-state; do
   not embed the parent `.rsn` as a UAC member.
2. Record flat **Set Name**, **Set URL**, **Source RSN**, and exactly four
   **Source .rsn Hashes** at package level: BLAKE3-256, CRC32, SHA-1, and MD5.
   Each hash record carries its digest, byte size, scope, and profile. Do not
   split one source file into Current and Initial catalogs.
3. Preserve each SPC member byte-for-byte. A track-name path such as
   `00-Track Name.spc` is a path-only transformation: retain its former path in
   `originalName` and record the rename in `transformations[]`.
4. Harvest each SPC with MetaManCore. Apply populated source-derived fields
   using canonical labels; retain all source ID666/xID6 tags in the unchanged
   SPC bytes. Do not serialize the generic nativeMetadata object into UAC
   member metadata; retain parser diagnostics in the conversion report.
5. Audit signature and revision byte for every SPC, malformed/truncated
   headers, xID6 boundaries/items, parser diagnostics, repeated tags, duplicate
   paths, duplicate streams, and cross-title/version content matches. Report
   textual-header versus version-byte disagreement separately from a package
   containing multiple valid SPC revisions.
6. For a package containing multiple byte-derived SPC revisions, record the
   set-level finding `mixed-format-version` and route the package to
   `Review/Mixed SPC Versions/<console>/`. Keep the actual **Format** tag on
   every member, including each valid non-default value; the
   tag itself is ordinary metadata, not an exception. Do not create an
   unsupported `criticalFlags` manifest field or put diagnostics in
   `game.metadata`.
7. Require four playable hashes per SPC, full UAC payload verification, and a
   complete member-path/size/BLAKE3 readback. Re-index the current paths in
   Songbase after promotion or review-folder moves.

For every source-set run, write a separate report with the SPC field coverage,
source-tag counts, parser diagnostics, header/revision inventory, invalid-file
count, exact package/member inventory, parent archive hash scopes, and review
findings. Do not put dated run counts in this evergreen procedure.

## Canonical tag vocabulary

Store new tag names directly in Title Case as listed below. Do not create a
lowercase or camelCase alias for the same tag. UAC structural properties such
as `game.title` and `game.console` keep their contract spelling; readers
continue to accept legacy lowercase tag names. A value-only edit preserves a
legacy key, and the Tag Analyzer shows the exact stored name.

| Display label | Canonical location | Rule |
| --- | --- | --- |
| Game ID | `game.metadata["Game ID"]` | Use the four-digit No-Intro ID from a unique, high-confidence AudioMan link. Do not invent or select among ambiguous release IDs. |
| Package title | `game.title` | Keep package title separate from all source tags until the identity/edit pass. |
| Game Title | `member.metadata["Game Title"]` | Preserve each source value, including arrays. Do not replace it with package `game.title`; route list-valued or varying packages to review. |
| Album | `member.metadata["Album"]` | Keep a distinct source Album as Album. Reconcile it against Game ID later; do not synthesize it from OST Title. |
| OST Title | `member.metadata["OST Title"]` | Preserve the xID6 source name and value separately from Album and Game Title. |
| Disc Number | `member.metadata["Disc Number"]` | Map the populated source OST Disc value to this tag; keep the numeric text exactly as recorded. |
| Region | `game.metadata["Region"]` | Include only when source or positive release-ID evidence establishes one region. Omit when unknown; use explicit variants when the package contains distinct regional releases. |
| System | `game.console` | Canonical value `Nintendo SNES`; do not repeat source synonyms such as `Super Nintendo` on each track. |
| Package Set | `game.metadata["Set Collection"]`, `game.metadata["Set Name"]`, `game.metadata["Set URL"]` | Store each populated source fact once as a direct Title Case package tag. New recipes accept the former nested `set` object and normalize it to these fields. |
| Title | `member.metadata["Title"]` | Project the SPC Song field when nonempty. |
| Artist | `member.metadata["Artist"]` | Project the source Artist field when present. |
| Year | `member.metadata["Year"]` | Preserve explicit Year or Copyright Year under the tag name Year. Keep it on the track; do not derive it from Date. |
| Date | `member.metadata["Date"]` | Preserve a populated source Date on the track. Keep ambiguous or unparsable text out of Date. |
| Genre | `member.metadata["Genre"]` or `game.metadata["Genre"]` | Include only when explicit; lift to package level only when every applicable track agrees, without duplication. |
| Comment | `member.metadata["Comment"]` | Preserve a nonempty source comment where it applies; keep archive-wide text in the original documentation member. |
| Dumper | `member.metadata["Dumper"]` | Preserve the source field name; do not rename it Encoded By. |
| Track Number | path-derived display field | Show the canonical zero-padded sequence prefix; do not turn raw hexadecimal OST Track codes into track numbers. |
| Game Version | `member.metadata["Game Version"]` or `game.metadata["Game Version"]` | Record a game build/revision only when source evidence identifies it. Store a shared value once at package level; retain track-specific revisions per member. Do not invent a revision or write an empty placeholder. |
| Format | `member.metadata["Format"]` | Record each member's actual SPC version, including repeated `SPC v.30`. Every valid value is ordinary member metadata, including values in a mixed-version package. Report the distribution and route mixed packages to review; review malformed, unreadable, or contradictory headers separately. |
| Stream Hashes | projection of `member.hashes[]` | Display four playable-payload hashes per track as a nested list labeled Stream BLAKE3-256, Stream CRC32, Stream SHA-1, and Stream MD5. Keep each algorithm, scope, and profile in the manifest record. |
| Source RSN, Source .rsn Hashes | package metadata and source record | Name the original source archive and expose exactly four hashes of that RSN as one nested list. Each item retains algorithm, digest, byte size, scope, and profile. |

Only populated source values become tags. Positive measured SPC timing fields
may be retained; zero or unavailable intro, loop, play, and fade values are
omitted. A millisecond timing value is not a sample-accurate loop point.
The SPC `Game` value is source evidence, not release identity. SPC `Album`
remains Album when present; `OST Title` is not an Album alias. The original SPC
bytes remain unchanged.

## Source-tag preservation

Copy each original SPC member byte-for-byte. This retains ID666 and xID6 data,
including original names, encoding, duplicates, unknown fields, and raw tag
bytes. Do not serialize an opaque **Native Metadata** field or redundant raw-tag
group in UAC member metadata. Put parser findings in the conversion report.
Do not repeat source archive names, URLs, or archive hashes on every track;
show them once with the package/source attachment and hash collection.

Map recognized source values to the canonical fields above. Preserve all
source tags in the unchanged SPC member. Do not edit source ID666/xID6 tags or
create aliases such as `dumper` beside Dumper or a duplicate Game Title.

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
an unchanged SPC member. Keep separately scoped raw-member records required by
the wrapper. Display the playable-payload records as the track's nested
**Stream Hashes** list with Stream-prefixed labels. Use eight uppercase
hexadecimal digits for CRC32 and lowercase hexadecimal for BLAKE3, SHA-1, and
MD5.

Reuse stored BLAKE3 and CRC32 values only after exact member bytes and hash
scope/profile match. Compute missing SHA-1 and MD5 over those same bytes. A
source-reported checksum is separate evidence: retain it with its origin and
scope, and do not substitute it for a locally verified hash. Hash equality
establishes byte identity only, not correct game identity, completeness, or
absence of a valid alternate version.

## Version and set-quality audit

Record the version identified by each SPC header in that member's single
**Format** tag, including repeated `SPC v.30` values. Do not add a separate
Sub-Container Version tag or replace per-member values with a verbose
`containedContainerVersions` inventory.
Valid version variation is normal per-member metadata. Report the set's
version distribution and route mixed-version packages to review while
retaining every member's actual tag. Route malformed, unreadable, or
contradictory headers to review separately. Audit game build/revision values
separately; they require source-backed evidence and must not be inferred from
an SPC format version. Do not rewrite the source header.

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

Record flat Set Name, Set URL, Source RSN name/path, and exactly four
**Source .rsn Hashes** at package level. Each list item holds one algorithm
(BLAKE3-256, CRC32/ISO-HDLC, SHA-1, or MD5), digest, byte size, scope, and
profile. Do not create Current/Initial duplicate catalogs or place historical
source hashes in the UAC archive-format checksum area. Each SPC member's four
playable-payload hashes appear together as **Stream Hashes** on that track.

SPC member paths use zero-based order and the embedded track title, such as
`00-Track Name.spc`. Keep the original RSN member filename in `originalName`
and record the byte-identical path rename in `transformations[]`.
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
