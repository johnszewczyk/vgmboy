# SNESMusic.org SPC tag cleanup preview

**Status: cleanup proposals remain under review.** The separate source-tag surfacing pass applied the **OST Disc** → **Disc Number** mapping; its [execution report](SNESMusicOrg-Source-Tag-Surfacing-Execution-2026-09-24.md) records that change. Other cleanup proposals in this report have not been applied. No SPC or RSN source bytes were changed.

## Audit scope

The indexed current collection contains 1,519 UAC packages and 34,917 playable SPC members. The open UACMan Tag Analyzer view was scoped to the 14-package `Nintendo Super Game Boy` folder, so its counts do not represent the full SNESMusic.org collection.

The counts below come from existing indexed UAC manifests and stored metadata. This pass did not re-hash or rescan the audio files.

The **Album / Game Title** mapping is held for review; see the separate [discrepancy report](SNESMusicOrg-Album-GameTitle-Discrepancy-2026-09-24.md). No UAC metadata change is proposed for those fields until the reader, projection, manifest, and GUI differences are reconciled.

## Proposed cleanup

| Current field / location | Current use in indexed manifests | Proposed UAC display / action |
| --- | --- | --- |
| Package `comment` | Present on 8 packages; each value matches `Comment` on its tracks and is populated in the manifest. | Remove the lowercase package duplicate. Keep per-track **Comment** with its source value and proper label. |
| Package `date` | Present on 9 packages; each value matches `Date` on its tracks and is populated in the manifest. | Remove the lowercase package duplicate. Keep per-track **Date**. |
| Package `encodedBy` / GUI “Encoded By” | Present on 1,063 packages. The value is already represented by per-track **Dumper** on 1,052 packages. In 11 packages it matches the full xID6 dumper value while each track also contains a shortened legacy ID666 value. | Remove package `encodedBy`. Keep one per-track **Dumper** value, preferring the full xID6 value where the current track value contains both shortened and full forms. |
| `source.extensions.audioman.initialSourceInventoryRunID` | Present on every package. It points to a Songbase inventory run; it is not SPC or set metadata. | Remove this Songbase run pointer from the UAC source record. Keep the source archive identity and its four hashes. |
| `Game Title` | Present on all 34,917 tracks. Its relationship to package `game.title` varies; see the discrepancy report. | Keep the existing field unchanged pending review. Do not replace it with **Album** or normalize its value in this pass. |
| `OST Title` | Present on 3,129 tracks; no literal **Album** field is present in the indexed track metadata. SPC xID6 calls this Official Soundtrack Title. | Keep the current value and label unchanged pending review. Do not map it to **Album** or discard it in this pass. |
| `OST Disc` | Present on 2,474 tracks; values are `1`, `2`, `3`, and `9`. | **Applied:** surfaced as **Disc Number**, preserving every value exactly. The SPC bytes retain `OST Disc`; the five `9` values remain unchanged. |
| `OST Track` | Present on 9,121 tracks. The values are source soundtrack track codes, not the sequential order of SPC members. The current conversion can render codes such as `0200` as 512, which explains the second, nonsensical Track # column. | Omit the raw `OST Track` field from the prominent UAC tag grid. Keep one **Track Number** based on the member filename/order. Leave all SPC source bytes unchanged. |
| `Source Encoding` | Present on all 34,917 tracks as parser-generated `Windows-1252`. | Remove from ordinary tags; this is a parser detail, not a source SPC tag. |
| `Sub-Container Version` | All 34,917 tracks have a version value: 34,916 say `SPC v.30`; one says `SPC v.10`. | Keep each actual value on its track, including every repeated v.30. `SPC v.10` is a valid tag, not an exception. Keep it on the track in the existing mixed-version package review path; the review applies to the package's version mixture, not the tag value. |

SPC xID6 field IDs identify `0x10` as Official Soundtrack Title, `0x11` as OST Disc, and `0x12` as OST Track. The specification describes the soundtrack disc number and a track code, which supports displaying the first two as Album and Disc Number while keeping the per-file sequence separate. [SPC/xID6 format description](https://wiki.superfamicom.org/spc-and-rsn-file-format)

## Keep as-is

- Per-track **Title**, **Artist**, **Publisher**, **Developer** (where already present), **Dumper**, **Year**, **Date**, and **Comment** retain their current values and proper Title Case display labels. Do not infer **Developer** from **Publisher** where it is absent. The current indexed manifests already have Title Case `Artist`, `Publisher`, and `Dumper` fields; **Album** is not currently present as a literal field.
- Keep the source `RSN` filename and the package-level four-item **Source .rsn Hashes** list. Keep each track’s four-item **Stream Hashes** list. These are existing source/member evidence, not the old archive-container hash inventory.
- Keep the flat package-level **Set Name** and **Set URL**, plus actual bundled text attachments. Do not expose format scans, schema versions, or inventory diagnostics as tags.
- Do not rewrite SPC ID666/xID6 data or other source bytes in this pass.

For example, the original SPC data for `02-Dracula's Theme.spc` in Super Castlevania IV has **Title** `Dracula's Theme`, **Game Title** `Super Castlevania 4`, **OST Title** `Demon Castle Dracula Best Vol. 2 (KICA-7506~7)`, source **OST Disc** `1` (surfaced in UAC as **Disc Number** `1`), **Track Number** `02`, **Artist** `Masanori Adachi, Taro Kudou`, **Publisher** and **Developer** `Konami`, **Dumper** `Datschge`, **Year** `1991`, and **Sub-Container Version** `SPC v.30`. Keep `OST Title` and `Game Title` distinct pending the discrepancy review. Its raw `OST Track` code `0200` would no longer create a second Track # value.

## Review points before applying

1. Reconcile Album, Game ID, package title, and Game Title in the later edit pass; see the separate Album / Game Title discrepancy report.
2. **Resolved:** map the populated source `OST Disc` metadata to **Disc Number** in UAC while preserving each value. See the source-tag surfacing preview and member ledger.
3. Decide separately whether raw `OST Track` stays prominent; this source-tag pass preserves its current UAC value and keeps the filename/order-based **Track Number** independent.

For the universal UAC method, **Sub-Container Version** is recorded per member whenever that member format defines an actual sub-container version. Uniform/default versions remain on each applicable member; they are not omitted or summarized into a package-level version inventory. A valid version value is ordinary metadata, not an exception; a mixed-version package still follows the set-level review rule.

The remaining cleanup proposals should produce a precise before/after metadata diff and verify UAC payloads without changing SPC bytes before they are applied. The completed Disc Number mapping is documented separately in the execution report.
