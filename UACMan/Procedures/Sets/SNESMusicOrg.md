# SNESMusic.org Set Profile

Apply the [Base Set Profile](BASE-SET-PROFILE.md) and the
[Nintendo SNES SPC profile](../SPC.md). These rules cover SNESMusic.org source
linkage, hash scopes, and identity enrichment.

## Scope

- **Collection** — Historic SNES soundtrack collection distributed as RSN
  archives containing SPC entries.
- **Format** — **SPC**; apply the SPC profile for source fields and UAC
  mappings.

## Source Authority

- **Package fields** — **Set Collection** `SNESMusic.org`, **Set Name**
  `Nintendo SNES`, **Set URL** `https://snesmusic.org/v2/torrent.php`.
- **First-pass eligibility** — This completeness-targeted set may use an
  ID-confirmed-only batch. Keep unmatched source items in AudioMan's set
  report until a later identity pass; do not infer exclusion from missing ID.
- **Source archive** — The original `.rsn`; it contains SPC entries but is not
  itself a UAC member.
- **Archive hashes** — Record BLAKE3-256, CRC32/ISO-HDLC, SHA-1, and MD5 for
  each complete source RSN as scoped hash records, not metadata tags.
- **SPC hashes** — Record the same four hashes for each complete, unchanged
  `.spc` under `uac-playable-payload-v1`; UACMan presents these as Stream
  Hashes.

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
