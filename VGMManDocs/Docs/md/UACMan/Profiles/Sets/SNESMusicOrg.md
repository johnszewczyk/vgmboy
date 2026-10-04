# SNESMusic.org Set Profile

Apply the [Base Set Profile](BASE-SET-PROFILE.md) and the
[Nintendo SNES SPC profile](../SPC.md). These rules cover SNESMusic.org source
linkage, hash scopes, and identity enrichment.

This document defines input rules for processing SNESMusic.org source data.
Record actual package coverage, completed tag changes, exceptions, and
verification results in AudioMan's per-set UAC dashboard report; use the
per-set ledger for operation history. AudioMan's ROM/set report remains the
authority for source membership, No-Intro identity, and completeness. This
profile defines only how confirmed values are represented in UAC packages.

## Scope

- **Collection** — Historic SNES soundtrack collection distributed as RSN
  archives containing SPC entries.
- **Format** — **SPC**; apply the SPC profile for source fields and UAC
  mappings.

## Source Authority

- **Package fields** — Use **Set Name** `SNESMusic.org` and **Set URL**
  `https://snesmusic.org/v2/torrent.php` throughout this UAC set. Do not split
  package source labels from `Downloaded from` claims in informational text;
  preserve those literal claims in the bundled documents. Do not add
  **Set Collection**.
- **Source archive** — The original `.rsn`; it contains SPC entries but is not
  itself a UAC member.
- **Archive hashes** — Keep BLAKE3-256, CRC32/ISO-HDLC, SHA-1, and MD5 for
  each complete source RSN in the permanent source-state database and the
  package-level **Source .rsn Hashes** list. Repeat that exact four-item list
  on every track extracted from the RSN, so each track carries a positive
  source identity.
- **SPC hashes** — Record the same four hashes for each complete, unchanged
  `.spc` under `uac-playable-payload-v1`; UACMan presents these as Stream
  Hashes.
- **Informational documents** — Keep source `info.txt` and other source TXT/HTM
  documents that carry historical or technical evidence as byte-preserved
  package assets. They are not SPC tracks; preserve them when rebuilding a
  package. Do not retain separate external metadata sidecars after useful
  structured values have been surfaced in the UAC; bundled source documents
  remain the evidence.
- **Document-derived metadata** — Inspect informational documents and report
  recurring key/value fields before proposing UAC tags. Do not generically
  promote colon-delimited lines, overwrite SPC-native tags, or create blank
  fields. Any AudioMan database ingestion must preserve source-document/member
  identity and checksums, and ingest only fields shown to be uniform and useful.
  Record findings and tag proposals in the per-set dashboard, not here.
- **Informational document fields** — Map `Dumped by` to package-level
  **Dumper** and `ID666 tags by` to package-level **Taggers**, retaining the
  exact values. Keep member-level SPC **Dumper** tags unchanged; the two scopes
  may differ.
- **Credit comparison** — Treat source `Dumped by` and SPC member `Dumper` as
  different scopes. Name-string comparisons flag candidates, not proven
  conflicts; manually review mismatches and likely aliases before changing any
  track tag. Never overwrite SPC-native values based only on fuzzy name matches.
- **Source URL claims** — Treat `Downloaded from` as a historical acquisition
  claim, not a source-class selector. All packages in this UAC set use the
  standard SNESMusic.org **Set Name** and **Set URL**. Keep the exact original
  claim in `info.txt`; do not add a redundant **Downloaded From** tag.
- **Track fields** — Map each SPC source **Game** name to track **Album**;
  retain **OST Title** separately when present. Record each member's actual
  sub-container version in **Format** (for example, `SPC v.30` or `SPC v.10`).
- **Game title and region** — Identify a game at the canonical No-Intro root
  title when the SNESMusic.org package title resolves to that one game, even
  when the source does not identify a regional release. Use the canonical game
  title in the package filename and **Region** `--` when region is unknown.
  Follow the Base Set Profile's collision-driven filename rule; never add an
  unknown-region marker to the filename.
  Only record a specific region when existing source metadata isolates it; do
  not infer one from a candidate No-Intro release. Keep source **Album** values
  unchanged while title/Album conflicts are reviewed.
- **Game ID field** — Copy a No-Intro **Game ID** only when existing evidence
  identifies one release ID. A canonical game-root title is sufficient to
  identify the game for naming and review, but does not justify choosing one
  regional/revision Game ID from several candidates. The package profile does
  not define No-Intro matching, source-set membership, or completeness rules.
  Keep **Game ID** separate from source **Album**.
- **Database enrichment** — Once a package has one positive **Game ID** and
  title conflicts are resolved, apply the approved aggregate metadata to UAC
  tracks while preserving source-native facts and provenance. Identity matching
  and review-queue decisions remain in AudioMan.

## Set Procedures

- **Source relationship** — Keep the source RSN and each derived SPC linked
  through their recorded source/member relationship.

## Required Checks

- **Hash verification** — Verify each source RSN's scoped hashes and its SPC
  member relationships.
- **UAC output report** — Record actual UAC tag coverage and exceptions in
  AudioMan's per-set UAC dashboard, separate from the ROM/set completeness
  report.
