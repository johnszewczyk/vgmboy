# SNESMusic.org Set Profile

Apply the [Base Set Profile](BASE-SET-PROFILE.md) and the
[Nintendo SNES SPC profile](SPC.md). These rules cover SNESMusic.org source
linkage, hash scopes, and identity enrichment.

This document defines input rules for processing SNESMusic.org source data.
Record actual package coverage, completed tag changes, exceptions, and
verification results in AudioMan's per-set UAC dashboard report; use the
per-set ledger for operation history. AudioMan owns source-set membership,
No-Intro matching, and ROM/set completeness. This profile defines only how
confirmed source and identity values are represented in UAC packages; it is
not a status report.

## Scope

- **Collection** — Historic SNES soundtrack collection distributed as RSN
  archives containing SPC entries.
- **Format** — **SPC**; apply the SPC profile for source fields and UAC
  mappings.

## Source Authority

- **Package fields** — For confirmed SNESMusic.org-source packages, use **Set
  Name** `SNESMusic.org` and **Set URL** `https://snesmusic.org/v2/torrent.php`.
  Keep the physical working set together for this pass; package-level
  Set Name/Set URL may identify a different confirmed source class. Do not add
  **Set Collection**.
- **Source archive** — The original `.rsn`; it contains SPC entries but is not
  itself a UAC member.
- **Archive hashes** — Keep BLAKE3-256, CRC32/ISO-HDLC, SHA-1, and MD5 for
  each complete source RSN in the permanent source-state database and the
  package-level **Source .rsn Hashes** list. Repeat that exact four-item list
  on every track extracted from the RSN, so each track carries a positive
  source identity.
- **Informational documents** — Preserve source `info.txt` and any additional
  TXT/HTM documents as package-level UAC assets, byte-for-byte. They are
  historical source material, not SPC tracks. Do not omit them when rebuilding
  a package.
- **Document-derived metadata** — Inspect informational documents and report
  recurring key/value fields before proposing UAC tags. Do not generically
  promote colon-delimited lines, overwrite SPC-native tags, or create blank
  fields. Any Songbase ingestion must preserve the source document/member
  identity and its checksum; ingest only fields shown to be uniform and useful.
  Record findings and tag proposals in the per-set dashboard report, not here.
- **Dumper and tagger fields** — Map info-document `Dumped by` to package-level
  **Dumper**, and `ID666 tags by` to package-level **Taggers**, preserving each
  exact source value. Keep SPC member-level **Dumper** tags unchanged; the
  package and member fields have different scopes. Surface mismatches in the
  AudioMan per-set UAC dashboard for review. String comparison produces review
  candidates, not proven conflicts; inspect name aliases and source scope before
  changing any SPC tag.
- **Set source fields** — Use **Set Name** `SNESMusic.org` and **Set URL**
  `https://snesmusic.org/v2/torrent.php` for every package in this set. Treat
  `Downloaded from` as a historical acquisition claim, not a source-class
  selector. Preserve the exact claim inside the bundled info document; do not
  add a redundant `Downloaded From` tag.
- **SPC hashes** — Record the same four hashes for each complete, unchanged
  `.spc` under `uac-playable-payload-v1`; UACMan presents these as Stream
  Hashes.
- **Track fields** — Map each SPC source **Game** name to track **Album**;
  retain **OST Title** separately when present. Record each member's actual
  sub-container version in **Format** (for example, `SPC v.30` or `SPC v.10`).
- **No-Intro identity** — Keep a positively matched **Game ID** separately
  from source **Album**. Copy the ID only after AudioMan has established a
  positive canonical match; this profile does not define No-Intro matching or
  set completeness. Leave list-valued and varying source titles for review.
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
  AudioMan's per-set UAC dashboard, separate from the ROM/set completeness
  report.
