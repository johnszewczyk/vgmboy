# Set-Based Procedures

These procedures record per-set authority, package naming, source retention,
provenance hashes, identity confidence, and review routing. They complement
format procedures such as [`../SPC.md`](../SPC.md).

## Profiles

- [`SNESMusicOrg.md`](SNESMusicOrg.md): historic SPC soundtrack archive;
  retain each original RSN in source-state and link it to derived UAC data.
- [`Project2612.md`](Project2612.md): historic Sega VGM collection; retain
  source package identity and scoped checksums. Its format-specific member
  projection is governed by the relevant format procedure.

## Shared rules

- Keep original source packages outside derived UAC payloads. Identify each
  source package once and record its four-hash current and initial checksum
  lists with explicit scope and profile.
- Use one nested list for repeated hash records. Do not bury hashes in generic
  metadata or duplicate a package hash on every track.
- Resolve package GameID from the AudioMan canonical database populated by the
  authoritative DAT. Require one unambiguous identity before canonical naming;
  route missing or ambiguous matches to a set-specific review folder.
- Hash matches prove byte identity only. They do not prove that two sets share
  provenance, membership authority, or canonical game identity.
