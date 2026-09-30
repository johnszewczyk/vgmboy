# Compact Pre-Disc Native Procedure

Apply the shared [UAC Base Profile](BASE-UAC-PROFILE.md). This procedure covers
compact, file-native, non-PCM music members such as SPC, VGM/VGZ, NSF/NSFE,
GBS, HES, and KSS. It does not cover decoded disc audio. Reader-specific tag
mappings belong in each format procedure; only SPC is currently approved
against its collection fixtures.

## File and playlist model

- Store each physical native file once. Subsongs and logical tracks are ordered
  playlist entries that point to the file and retain their source indexes.
- Preserve source-authored order and repeated indexes. Do not copy a member or
  multiply its metadata and hashes for each playlist entry.
- Preserve companion playlists such as M3U files when they contribute titles,
  order, timing, or loop behavior. Keep their original bytes as package assets.
- Keep the exact playable source bytes in the member. For explicit container
  normalization such as VGZ to VGM, record the transformation and hash the
  normalized member according to the format profile.

## Required Checks

Check each format profile for its exact playable byte scope and reader-specific
signature, header, version, track-count, chunk, and offset constraints. Compare
playlist references with source indexes. Report malformed input, parser
diagnostics, and duplicate streams; a duplicate match alone does not authorize
removing a valid alternate version. Apply the shared hash and timing rules in
[`Procedures README`](README.md#hash-and-timing-scope), then verify the written
UAC and read back its member paths, sizes, and source-byte identity.

Keep fixture and collection findings in dated reports. A profile stays draft
until its representative fixtures, package checks, and UACMan field visibility
have been verified.
