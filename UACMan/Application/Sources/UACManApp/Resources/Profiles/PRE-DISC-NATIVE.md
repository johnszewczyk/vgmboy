# Compact Pre-Disc Native Procedure

Apply the shared [UAC Base Profile](BASE-UAC-PROFILE.md). This procedure
covers compact, file-native, non-PCM formats such as SPC, VGM/VGZ, NSF/NSFE,
GBS, HES, KSS, and S98. It does not cover decoded disc audio. Reader-specific
fields belong in each format's mapping table; only SPC is approved against its
collection fixtures.

## File and Playlist Model

- **Physical members** — Store each native file once. Subsongs and logical
  tracks are ordered playlist entries with their source indexes.
- **Ordering** — Preserve source-authored order and repeated indexes. Do not
  copy a member or multiply its metadata and hashes for playlist entries.
- **Companion playlists** — Preserve M3U files when they contribute titles,
  order, timing, or loop behavior. Keep their original bytes as package assets.
- **Member bytes** — Preserve the exact playable source. For explicit
  normalization such as VGZ to VGM, record the transformation and hash the
  normalized member as its format profile specifies.

## Required Checks

- **Format validation** — Follow each profile's signature, header, version,
  track-count, chunk, offset, and playable-byte-scope checks.
- **Playlist references** — Compare playlist references with source indexes.
- **Diagnostics and duplicates** — Report malformed input, parser diagnostics,
  and duplicate streams. A duplicate match alone does not authorize removing
  a valid alternate version.
- **Package verification** — Apply the shared hash and timing rules in the
  `VGMManDocs > UACMan > Procedures > README.md > Hash and timing scope`, verify the written UAC,
  and compare member paths, sizes, and source-byte identity.
- **Approval evidence** — Keep fixture and collection findings in dated
  reports. A profile stays draft until fixtures, package checks, and UACMan
  field visibility have been verified.
