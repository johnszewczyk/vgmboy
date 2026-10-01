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
- **Informational document fields** — Keep each source `info.txt` as a
  byte-preserved package asset. Map `Dumped by` to package-level **Dumper** and
  `ID666 tags by` to package-level **Taggers**, retaining the exact values.
  Keep member-level SPC **Dumper** tags unchanged; the two scopes may differ.
  Do not retain external metadata sidecars once their useful structured values
  have been surfaced in the UAC; the bundled source document remains evidence.
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
- **Game ID field** — Copy **Game ID** only after AudioMan's ROM/set process
  establishes a positive canonical match. The package profile does not define
  No-Intro matching, source-set membership, or completeness rules. Keep
  **Game ID** separate from source **Album**.
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
