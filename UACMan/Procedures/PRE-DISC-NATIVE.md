# Compact Pre-Disc Native Music Profile

## Status and scope

Shared policy for compact, file-native, non-PCM game-music formats whose
stored member is the music program/container itself. It includes SPC, VGM/VGZ,
NSF/NSFE, GBS, and other supported golden-era pre-disc formats such as SID,
AY/SAP, HES, KSS, and S98 once their reader profiles define the member scope.
Format-specific field mappings live in the linked profiles. This policy does
not apply to decoded CD audio or other large PCM streams. VGM, NSF/NSFE, and
GBS mappings are drafts until representative fixtures have been checked
against the reader and UACMan GUI.

These profiles use the shared [canonical system names](CANONICAL-SYSTEM-NAMES.md)
for package-level `game.console`. Do not duplicate that identity as a member
tag.

## Common member rules

- Preserve the complete source member bytes. Put populated, useful, source-backed
  values in direct Title Case tag fields; omit blanks, reader defaults, and
  invented aliases. Keep undecoded details in the retained member or a dated
  report.
- Use one **Format** tag on each member. Put format and actual container version
  in one value when a version exists, such as `SPC v.30`, `VGM v.1.71`,
  `NSF v.1`, or `GBS v.1`. Repeat a uniform version on every member. For a
  format without a version, use its concise format name. Never add a parallel
  Sub-Container Version field or package inventory.
- Calculate four `uac-playable-payload-v1` hashes for every physical native
  file: BLAKE3-256, CRC32/ISO-HDLC, SHA-1, and MD5. Hash the exact playable
  member scope defined by its format profile. Do this once per file, regardless
  of the number of subsongs or playlist entries. Keep the separate raw-member
  integrity records required by the UAC wrapper.
- Let the UAC packer hash bytes while writing the UAC. Reuse database hashes
  only when algorithm, exact bytes, scope, and profile match; otherwise compute
  the missing values during packaging. Do not separately rescan already
  verified data to build duplicate hash tables.
- Hashes belong in UAC's integrity/hash model and Stream Hashes view, not in
  invented music-tag keys. A hash is byte identity evidence, not game
  identification or proof that a set is complete.
- Store a physical file once and represent subsongs through ordered playlist
  entries. Preserve authored order and repeated indexes. Do not multiply file
  hashes or member metadata into one copy per subsong.
- Keep positive source-authored timing when a consumer needs it. Do not expose
  parser defaults, estimated durations, or raw timing counters as music tags.
  A duration in milliseconds is not itself a sample-accurate loop instruction.
  Preserve positive loop data only when the native format or companion data
  carries it and the player uses it; never record a negative “no loop” value.

## Validation before promotion

Check signature, minimum header size, version, declared track count, chunk or
offset bounds, and reader diagnostics. Compare playlist entries to source
indexes; detect duplicate member bytes without deleting a valid alternate
version. Inspect any companion playlist/M3U as source evidence and preserve its
bytes when it contributes titles, order, timing, or loop playback behavior.
Verify `uacman inspect --verify`, then unpack and compare member paths, sizes,
source bytes, and all four playable hashes. Keep format fixture reports in
`Procedures/Reports/` and do not mark a profile complete before fixture and GUI
field visibility are confirmed.
