# SNESMusic.org source-tag surfacing preview

**Status: applied on 2026-09-24.** This document preserves the pre-change evidence and mapping preview. The approved **OST Disc** → **Disc Number** mapping, high-confidence package **Game ID** assignments, and **Game Title** conflict routing have been applied; see the [execution report](SNESMusicOrg-Source-Tag-Surfacing-Execution-2026-09-24.md). The source SPC and RSN files were not changed.

## Current evidence

The current indexed SNESMusic.org collection has 1,519 UAC packages. Current manifests contain 470,557 member-tag entries. There are 98 packages with list-valued **Game Title** members and 38 packages with per-track value variation; 130 packages are in the union (6 overlap). The review ledger records the exact source values and candidate No-Intro IDs. No blank package or member metadata values were found.

The current manifests contain **OST Title** on 3,129 tracks and contain no literal **Album** member field. The SPC reader labels the xID6 soundtrack field **OST Title**; its normalized Album projection is deliberately not added to UAC. Therefore this pass preserves **OST Title** verbatim, does not manufacture an **Album** value from it, and leaves any genuine Album/Game ID comparison for the later edit pass.

Every SPC track already has **Sub-Container Version**, with each member's actual version retained. **OST Disc** occurs on 2,474 tracks in 69 packages; all values are populated strings (`1`: 1,923, `2`: 439, `3`: 107, `9`: 5), with no existing **Disc Number** keys. The approved mapping is to surface these values as **Disc Number**, preserving each value exactly. The [Disc Number ledger](SNESMusicOrg-Disc-Number-Preview-2026-09-24.tsv) lists every member. Existing **Stream Hashes** and package-level **Source .rsn Hashes** remain unchanged. Source SPC bytes are not in scope.

## Applied work

- Added populated source **OST Disc** values as **Disc Number** on 2,474 tracks across 69 packages, preserving each value exactly. The ledger lists every package/member mapping.
- Added package-level **Game ID** to 316 packages whose AudioMan canonical-title link is high confidence, has exactly one Nintendo SNES No-Intro ID, and whose track **Game Title** is scalar and consistent. The tag value is the four-digit DAT ID, preserving leading zeros. The exact mapping and existing title value are in [the Game ID ledger](SNESMusicOrg-Source-Tag-GameID-Preview-2026-09-24.tsv).
- Moved the 130 packages with list-valued or per-track-varying **Game Title** to `Review/Game Title Conflicts/Nintendo SNES/`, preserving their full source tag values. No list was flattened and no value was promoted. Exact destinations and existing values are in [the review-routing ledger](SNESMusicOrg-GameTitle-Review-Routing-Preview-2026-09-24.tsv).
- Leave all other packages' metadata and paths as-is. Medium-confidence, multiple-ID, non-SNES, and unmatched records receive no guessed **Game ID** in this pass.

## Tag boundary for this pass

Track-level source names remain as surfaced: **Title**, **Game Title**, **Album** only when a distinct source Album field exists, **OST Title**, **Artist**, **Publisher**, **Developer** when present, **Dumper**, **Year**, **Date**, **Comment**, **Disc Number** (from source **OST Disc**), **OST Track**, **Track Number**, and **Sub-Container Version**. A **Game ID** tag is package-level and independent of package `game.title`, track **Game Title**, and **OST Title**. No blank values are introduced.

UACMan's **Album** convenience column is not proof that an Album tag is present; the current manifest audit found zero literal Album member fields. The existing tag records remain in the manifest, where the Tag Analyzer reads package/member metadata.

This source-tag pass renames the UAC metadata key **OST Disc** to **Disc Number** without changing the SPC bytes, and adds package-level **Game ID** for the listed unique matches. The 130 conflict packages remain unflattened in review. A later edit pass can reconcile Album, Game Title, and package title after source multiplicity and identity are reviewed.
