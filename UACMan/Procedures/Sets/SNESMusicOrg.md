# SNESMusic.org Set Procedure

Apply the [Base Set Profile](BASE-SET-PROFILE.md) and the
[Nintendo SNES SPC procedure](../SPC.md). The set-specific rules here cover
SNESMusic.org source linkage, hash scopes, and identity enrichment.

## Set source

- Set Name: `SNESMusic.org`.
- Set URL: `https://snesmusic.org/v2/torrent.php`.
- The source archive is the original `.rsn`, which contains SPC entries; the
  RSN itself is not a UAC member.
- Record four checksums for each complete source RSN: BLAKE3-256,
  CRC32/ISO-HDLC, SHA-1, and MD5. Store them as scoped hash records, not as
  ordinary metadata tags.
- Each complete, unchanged `.spc` member has the four
  `uac-playable-payload-v1` hashes. UACMan presents these as Stream Hashes.

## Identity enrichment

The identity pass uses the AudioMan canonical-game database populated from the
No-Intro SNES DAT. Apply its result using the positive-match and uncertainty
rules in the Base Set Profile.

## Package checks

Verify each source RSN's hashes and the SPC member relationships recorded for
it. Keep collection counts and exceptions in dated reports under `Reports/`.
