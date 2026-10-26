# Major Audio Profile Review — 2026-10-26

## Scope

This review covers the native formats that dominate the current UAC music
collection: SPC, VGM/VGZ, GBS, and USF/miniusf. A manifest-only inventory read
12,298 UAC manifests and counted 97,616 SPC playable members, 95,366 VGM
playable members, 2,265 GBS playable members, 3,066 USF playable members, and
35 miniUSF playable members. The inventory did not verify embedded payload
bytes or recompute any member hashes.

The selected profiles define source-to-UAC mappings and fixture behavior.
Production package conversion, playlist reconciliation, and admission remain
per-set reviews in AudioMan.

## Profile Disposition

- **SPC** — Preserve native `Game` as member `Album`, native `Song` as
  `Title`, and the actual header revision as member `Format`. Keep xID6
  `OST Title` separate. Positive source timing is retained; parser fallbacks
  are omitted. A real SPC UAC fixture passed the MetaMan harvest and
  manifest-only rewrite integration; the rewritten UAC payload bytes matched
  the source package exactly.
- **VGM/VGZ** — Map populated GD3 fields directly, keep VGM version on each
  member, and package raw VGM after one VGZ gzip-layer removal. Wrapper fixtures
  passed pack/unpack, stream-hash, version, and preservation checks.
- **GBS** — Keep shared header identity at package scope and logical track
  identity/order in playlist entries. Preserve M3U source bytes exactly and do
  not project M3U timing hints. Wrapper fixtures passed ordered-subsong and
  byte-preserving pack/unpack checks; MetaMan and UAC projection checks passed.
- **USF/miniusf** — Keep the PSF v0x21 version on playable members and preserve
  `.usflib` dependencies as library assets. The existing USF profile records
  real-source UAC fixture review and a 389-package source scan. This review
  keeps the other PSF-family extensions pending their own checks.

## Verification Evidence

- MetaMan — 180 tests passed:

  ```sh
  swift test --package-path MetaMan --disable-sandbox
  ```

- UACMan — 34 tests passed, including a real-container SPC harvest and a
  temporary manifest rewrite with payload equality:

  ```sh
  UACMAN_REAL_SPC_PACKAGE="/Users/john/Downloads/audio/JohnS/Nintendo SNES (Review)/Identity/Bike Daisuki! Rider's-Spirits.uac" \
    swift test --package-path UACMan --disable-sandbox
  ```

- UAC wrapper — 29 tests passed:

  ```sh
  PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover \
    -s UACMan/Wrapper/python/tests -p 'test_*.py'
  ```
- Live manifest samples were inspected for SPC, VGM, and GBS package field scopes. The live package inventory was manifest-readable; payload verification was not part of this scan.

## Hash and Collection Boundary

The UAC manifest remains authoritative for member, stream, source, and CRC
hashes. Songbase and the Museum keep their hash-free UAC metadata projections;
content comparisons read the current UAC manifest. Fixture verification does
not approve or rewrite a collection package. Use the applicable format and set
profiles plus the AudioMan per-set report for each conversion or correction.
