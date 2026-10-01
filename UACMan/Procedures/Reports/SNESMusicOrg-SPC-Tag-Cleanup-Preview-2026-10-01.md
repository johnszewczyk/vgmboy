# SNESMusic.org SPC tag cleanup preview

**Status: proposed pass for review; no UAC packages have been changed.** This
preview supersedes the September 24 cleanup proposal where the mapping or hash
placement differs. It reflects the current SNESMusic.org and SPC profiles.
Profiles are human-readable instructions; they do not configure or run UACMan.
This preview records proposed input rules only. After an approved pass, actual
coverage, changes, exceptions, and verification results belong in AudioMan's
`reports/SNESMusicOrg/Nintendo SNES/` dashboard output and the SNESMusic.org
per-set ledger, not in the profile notes.

## Audit scope

The current manifest-only census found 1,519 UAC packages and 34,917 SPC
tracks. It read package manifests without verifying or re-hashing SPC, RSN, or
UAC payload bytes. Existing package-level **Source .rsn Hashes** lists contain
four algorithms; this pass proposes to repeat each list on its tracks without
recomputing any digest.

## Proposed metadata changes

| Current field | Current coverage | Proposed result |
| --- | ---: | --- |
| Track **Game Title** | 34,917 tracks; values include arrays and per-track variations | Rename the source game name to track **Album**, preserving each value, array, and order. Do not normalize values or rewrite SPC ID666/xID6 bytes. Keep the 130 packages already in `Review/Game Title Conflicts/Nintendo SNES/` there for later value reconciliation. |
| Package **Set Name** / **Set URL** | 1,519 packages | Keep `SNESMusic.org` and `https://snesmusic.org/v2/torrent.php`. Do not add **Set Collection**. |
| Package **Source .rsn Hashes** | 1,519 packages, four hashes each | Keep the existing package list and permanent Distribution Museum claims; copy the exact list to every extracted SPC track as **Source .rsn Hashes**, giving each track a positive parent-source identity. No archive hashing. |
| Track **Stream Hashes** | Four source/member hashes per SPC track in the current set | Keep unchanged. No stream hashing. |
| Track **Sub-Container Version** | 34,916 `SPC v.30`; one `SPC v.10` | Rename the tag to **Format**, retaining the exact per-track version string. The v.10 value is valid metadata; the package remains in the existing mixed-version review location if applicable. |
| Track **Source Encoding** | 34,917 `Windows-1252` parser labels | Remove; this is parser detail, not a source tag. |
| Track **OST Track** | 9,121 encoded xID6 values | Remove from the tag surface; do not turn the encoded value into a second or nonsensical **Track Number**. Keep the existing filename/order-based Track Number and **Disc Number**. |
| Package `encodedBy` | 1,063 packages | Remove the mislabeled package field. Retain track **Dumper**; where the track currently has the shortened ID666 value and the package field has the full xID6 value, use the full xID6 Dumper value on the track (11 packages). |
| Package `comment` / `date` | 8 / 9 packages | Remove lowercase package duplicates only; retain the populated track **Comment** and **Date** values. |
| `sources[].extensions.audioman.initialSourceInventoryRunID` | 1,519 packages | Remove the obsolete Songbase inventory-run pointer; preserve source identity and hash evidence. |
| Empty metadata fields | None found in the census | Add no blank tags; preserve this rule. |

Keep **OST Title** separate from **Album**, and preserve populated **Artist**,
**Publisher**, **Developer**, **Dumper**, **Year**, **Date**, and **Comment**.
Keep confirmed package **Game ID** values separate from source Album values.
Do not rename package files in this pass.

## Fields left for a separate playback review

The current manifests also contain source timing fields such as **Length
(seconds)**, **Intro Length (ms)**, **Fade (milliseconds)**, **Fade Length
(ms)**, and **Loop Count**. This pass leaves them untouched because they may
carry playback information; any migration to UAC playback fields or omission
should be proposed separately with the SPC playback rules and consumer use in
view.

## Verification boundary for an approved pass

- Apply manifest-only rewrites. Preserve each UAC payload and every source SPC
  byte; do not edit RSNs or SPC ID666/xID6 blocks.
- Verify each written UAC manifest and its unchanged payload; retain the four
  existing **Stream Hashes** and package **Source .rsn Hashes** while adding
  the same RSN list to each track.
- Re-index changed UAC package identities in Songbase and leave the existing
  Distribution Museum source-file identities intact. Do not create Songbase
  rollback snapshots or hash source RSN/SPC files.
- Keep title-conflict and mixed-version review routing intact and record exact
  before/after metadata in the SNESMusic.org set ledger and execution report.
