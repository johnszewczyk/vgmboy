# SNESMusic.org Set Profile

Apply the [Base Set Profile](BASE-SET-PROFILE.md) and the
[Nintendo SNES SPC profile](../SPC.md). These rules cover SNESMusic.org source
linkage, hash scopes, and identity enrichment.

This document defines input rules for processing SNESMusic.org source data.
Record actual package coverage, completed tag changes, exceptions, and
verification results in AudioMan's SNESMusic.org per-set dashboard report;
use the per-set ledger for operation history. Do not treat this profile as a
status report.

## Scope

- **Collection** — Historic SNES soundtrack collection distributed as RSN
  archives containing SPC entries.
- **Format** — **SPC**; apply the SPC profile for source fields and UAC
  mappings.

## Source Authority

- **Package fields** — **Set Name** `SNESMusic.org` and **Set URL**
  `https://snesmusic.org/v2/torrent.php`. Do not add **Set Collection**.
- **First-pass eligibility** — This completeness-targeted set may use an
  ID-confirmed-only batch. Keep unmatched source items in AudioMan's set
  report until a later identity pass; do not infer exclusion from missing ID.
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
- **Track fields** — Map each SPC source **Game** name to track **Album**;
  retain **OST Title** separately when present. Record each member's actual
  sub-container version in **Format** (for example, `SPC v.30` or `SPC v.10`).
- **No-Intro identity** — Keep a positively matched **Game ID** separately
  from source **Album**. Do not normalize or reconcile source title values in
  this source-tag pass; leave list-valued or varying cases in the review path.
- **Database enrichment** — Once a package has one positive **Game ID** and
  title conflicts are resolved, apply the database's aggregated metadata to
  its UAC tracks, preserving source-native facts and provenance. Keep unresolved
  or conflicting work out of the completed queue until reviewed. After the
  completed UAC is verified, its derived working item may move to `_done`;
  this does not authorize retiring the original RSN or its source-state record.

## Identity Enrichment

- **Identity source** — Use the AudioMan canonical-game database populated
  from the No-Intro SNES DAT.
- **Match rule** — Apply its result only after a positive, unique match under
  the Base Set Profile. Keep unresolved releases unresolved.

## Set Procedures

- **Source relationship** — Keep the source RSN and each derived SPC linked
  through their recorded source/member relationship.

## Required Checks

- **Hash verification** — Verify each source RSN's scoped hashes and its SPC
  member relationships.
- **Collection report** — Keep counts and exceptions in dated reports under
  `Reports/`.
