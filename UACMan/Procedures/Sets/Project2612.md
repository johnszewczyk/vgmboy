# Project 2612 Set-Based Procedure

Project2612 is a historically authoritative Sega music collection and must
retain its source-state relationship when represented in UAC. The source tree
currently contains per-game `.tar.zst` packages; those are source packages, not
the deprecated derived-output format. Do not infer lineage from JoshW or other
collections based on matching titles or hashes.

## Required source linkage

- Record the Project2612 set name and exact source URL from the applicable
  source record.
- Preserve each original source package in source-state, outside the UAC
  payload. Record its name/path as **Source Archive**.
- Keep a nested **Archive Hash** collection with four **Current Checksums**
  for current source bytes and four **Initial Checksums** for the original
  source-state bytes: BLAKE3-256, CRC32/ISO-HDLC, SHA-1, and MD5.
- Record track/member hashes at their actual format-defined byte scope. Do not
  call a compressed-file checksum a stream checksum.
- Resolve GameID and canonical naming through the AudioMan database populated
  from the appropriate No-Intro DAT. Route unidentified or ambiguous records
  to review instead of guessing from filenames.

## Scope and open details

The package tree includes multiple platforms and formats. Apply the matching
format procedure to each member, and record platform-specific identity and
revision limits in the dated set report. Do not apply SNESMusic.org SPC field names,
RSN labels, or version assumptions to Project2612 packages.
