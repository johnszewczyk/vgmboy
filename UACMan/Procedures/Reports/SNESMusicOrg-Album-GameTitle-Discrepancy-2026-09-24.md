# SNESMusic.org Album / Game Title discrepancy report

**Status: source-tag rules clarified; value reconciliation deferred.** The 130 packages with list-valued or varying **Game Title** entries have been routed to `Review/Game Title Conflicts/Nintendo SNES/` without flattening or promotion. This report records the manifest and reader/projection differences; the later title edit pass remains deferred. Counts are from indexed manifests; this audit did not rescan or re-hash SPC payloads.

## Findings in the current indexed set

The audit covers 1,519 SNESMusic.org UAC packages and 34,917 playable SPC tracks.

The [package-level discrepancy ledger](SNESMusicOrg-GameTitle-Discrepancies-2026-09-24.tsv) records the exact values, member paths, and counts for 673 packages with a title mismatch, multiple **Game Title** representations, or **OST Title** / **Album** data relevant to this mapping.

| Field / comparison | Finding |
| --- | --- |
| Track **Game Title** | Present on all 34,917 tracks: 32,765 scalar values and 2,152 list values, with 1,569 distinct stored value representations. |
| Package `game.title` vs track **Game Title** | On all tracks, 19,926 values exactly equal the package title, 66 differ only by case, and 14,925 differ beyond case. At package level, 888 packages have an exact match on every track, 2 differ only by case, and 629 contain a non-case difference. These differences can be source aliases, punctuation, regional labels, truncation, or title normalization; they have not been classified or corrected. |
| Intra-package **Game Title** consistency | 38 packages contain more than one distinct stored **Game Title** value representation across tracks. Some values are arrays. Their original SPC tags need examination before deciding whether a value is a duplicate-tag alternative, a source inconsistency, or a parser/harvest artifact. |
| List-valued / varying **Game Title** review | 98 packages contain list-valued track entries and 38 vary across tracks; 6 are in both groups. The 130-package union is in `Review/Game Title Conflicts/Nintendo SNES/`, without flattening or promoting values. |
| Track **Album** | No literal `Album` field appears in the 34,917 current member metadata records. |
| Track **OST Title** | Present on 3,129 tracks, with 80 distinct values. It co-occurs with **Game Title** on all 3,129. The two values are equal on 264 tracks and differ on 2,865. |

### Example: Super Castlevania IV

For `02-Dracula's Theme.spc`, the current package title is `super castlevania iv`; the track's **Game Title** is `Super Castlevania 4`; the track's **OST Title** is `Demon Castle Dracula Best Vol. 2 (KICA-7506~7)`; and **Title** is `Dracula's Theme`. There is no literal **Album** field in this member record. The package title is also not yet an unambiguous No-Intro release identity, so it should not be used as the authority for rewriting the embedded SPC value.

These values describe at least two different concepts: game identity and soundtrack-release title. Similarity between them on some tracks does not make them interchangeable.

## Why the current tools disagree

- The SPC reader in [`SPCMetadataReader.swift`](../../../MetaMan/Sources/MetaManCore/SPCMetadataReader.swift) assigns xID6 `OST Title` to normalized `fields.album`. The v0.30 SPC format specification defines xID6 `0x10` as **Official Soundtrack Title**, separately from ID666/xID6 **Game**; it also defines `0x11` as **OST Disc** and `0x12` as **OST Track**. [SPC File Format Specification v0.30](https://pt.scribd.com/document/284944577/SPC-File-Format)
- The current UAC SPC projection in [`SPCMetadataProjection.swift`](../../Application/Sources/UACManCore/SPCMetadataProjection.swift) removes the normalized `album` field, with a comment that an SPC soundtrack is a game rather than an album.
- The current [`SPC.md`](../SPC.md) says `OST Title` is not an Album alias, while the reader does normalize it to Album. Current indexed UAC members instead expose `OST Title` and `Game Title`, with no `Album` key.
- This means the discrepancy is not only inconsistent game-name text. The reader, UAC projection, procedure, and visible manifest currently apply different rules to the soundtrack title.

The visible **Album** column is a generic UACMan convenience field. The track table reads `member.album`; the Tag Analyzer's package Album context searches package/member metadata for a literal `Album` key. Neither creates a source tag. Since current SNESMusic.org manifests have no literal `Album` key, an empty Album column does not mean `OST Title` was lost or converted. The source tag remains visible as **OST Title** where present.

## Open mapping questions

1. **Resolved:** preserve xID6 **OST Title** under its source name. Keep a distinct source **Album** separately when one exists; do not derive Album from OST Title.
2. **Resolved for source surfacing:** preserve track **Game Title** values as stored and add a separate package-level **Game ID** only for a unique, high-confidence No-Intro match. Reconcile package title, Game ID, Game Title, Album, and OST Title in the later edit pass.
3. **Resolved for now:** route the 130 list-valued or varying Game Title packages to review. Keep each stored list and value intact; do not select a representative value.
4. **Resolved:** UACMan's Album column is a generic convenience field backed by `member.album`; it is not proof that a literal Album tag exists in the manifest. The Tag Analyzer's Album value is likewise derived only from an actual `Album` metadata key.

## Handling until resolved

- Preserve the current **Game Title** and **OST Title** values as distinct evidence. The list-valued or varying Game Title packages are in the review path recorded in the [source-tag surfacing preview](SNESMusicOrg-Source-Tag-Surfacing-Preview-2026-09-24.md); do not rename, deduplicate, flatten, or discard their tags.
- Do not infer the canonical game title from `OST Title`, and do not use an unresolved package title to overwrite the SPC's embedded **Game Title**.
- Keep original SPC ID666/xID6 bytes unchanged. Record exact per-track disagreements in the eventual before/after proposal, grouped by package and source value.
- Update the **Album** / **Game Title** SPC-to-UAC mapping rule only after these discrepancies and the UI source have been reviewed.
