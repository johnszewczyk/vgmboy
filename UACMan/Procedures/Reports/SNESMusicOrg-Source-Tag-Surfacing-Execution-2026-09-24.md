# SNESMusic.org source-tag surfacing execution

**Status: completed on 2026-09-24.** This records the applied changes from the [source-tag preview](SNESMusicOrg-Source-Tag-Surfacing-Preview-2026-09-24.md). The source SPC and RSN files were not edited.

## Changes applied

- Mapped populated source **OST Disc** metadata to track **Disc Number** on 2,474 tracks in 69 packages. Values were retained exactly: `1` (1,923 tracks), `2` (439), `3` (107), and `9` (5). No blank values were added; no current track retains the old UAC key **OST Disc**.
- Added package-level **Game ID** to 316 high-confidence packages with one consistent Nintendo SNES No-Intro ID. These remain separate from package `game.title`, track **Game Title**, **Album**, and **OST Title**.
- Moved 130 packages with list-valued or varying **Game Title** to `Review/Game Title Conflicts/Nintendo SNES/`. Their source values remain intact. Five of these packages also received a metadata update.
- The collection remains 1,519 UAC packages. No package or track payload was removed. The 376 packages with metadata changes had their outer UAC identities refreshed in Songbase; unchanged package wrappers were not rehashed.

## Source-state and database record

- All 1,519 current package manifests retain exactly four **Source .rsn Hashes** entries. The path-independent Distribution Museum contains 1,519 SNESMusic.org source occurrences and 6,076 hash records (four algorithms per source object).
- The original `.rsn` archives remain outside the UAC packages: the current 1,519 manifests contain zero `.rsn` members. Their source names and four-hash records remain the package-level linkage.
- All 34,917 SPC member **Stream Hashes** lists and source Sub-Container Version values remain as before. No SPC or RSN source file was hashed. Only the 376 changed outer `.uac` files were hashed to refresh package identities.
- Songbase path migration updated 64,840 exact path references and recorded 130 review aliases. Current package indexing still resolves to 1,519 packages.

## Verification

- `uacman.read_uac(..., verify_payload=True)` verified the payload on all 376 metadata-updated UAC packages. The manifest edits did not change their payload bytes.
- Indexed current manifests report 316 package **Game ID** tags, 2,474 track **Disc Number** values, zero remaining **OST Disc** values, and four source RSN checksums in every package.
- Songbase and the Distribution Museum both pass `PRAGMA quick_check`; both report zero foreign-key violations.

## Deferred review

No Album, Game Title, OST Title, or package-title values were reconciled. The conflict packages remain available under the review path with their lists and per-track values intact. Canonical naming and the later title-edit pass remain separate from this source-tag surfacing step.
