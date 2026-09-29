# Nintendo SNES SPC Profile

Apply the [UAC Base Profile](BASE-UAC-PROFILE.md) and
[Pre-Disc Native Procedure](PRE-DISC-NATIVE.md). This profile maps MetaManCore's
`spc` reader for SPC ID666 and xID6 data. The reader does not start an emulator;
see [`MetaMan/FORMAT-LAYOUTS.md`](../../MetaMan/FORMAT-LAYOUTS.md).

## Field mapping

| Source fact | UAC location | Type and normalization | Omission or review rule |
| --- | --- | --- | --- |
| System | `game.console` | `Nintendo SNES` | Set once per package. |
| Verified No-Intro identity | `game.metadata["Game ID"]` | Four-digit ID | Add only for a unique, high-confidence release match. |
| SPC `Game` | `member.metadata["Game Title"]` | Populated source text | Keep separate from `game.title` and **Album**. Preserve lists and variation. |
| SPC `Song` | `member.metadata["Title"]` | Populated source text | Omit empty values. |
| xID6 `OST Title` | `member.metadata["OST Title"]` | Populated source text | Keep as soundtrack title; do not alias it as **Album**. |
| xID6 `OST Disc` | `member.metadata["Disc Number"]` | Preserve source value | Do not infer an OST disc. |
| xID6 `OST Track` | `member.metadata["OST Track"]` | Preserve source value | It is not display order or **Track Number**. |
| Artist, Dumper, Publisher, Comment | Direct `member.metadata` fields | Populated Title Case values | Keep source meaning; omit empty fields. |
| Explicit release date | `member.metadata["Date"]` | Populated source date | Do not use source-capture time. |
| SPC Copyright Year | `member.metadata["Year"]` | Populated source year | Distinct from an explicit release date; do not derive one from the other. |
| Track display order | Path-derived display value | Zero-padded member path prefix | Do not derive it from raw hexadecimal `OST Track`. |
| SPC revision byte | `member.metadata["Format"]` | `SPC v.<revision>` | Use the byte-derived revision. Report disagreement with the textual header separately. |
| Positive source timing | Supported member timing fields | Source-backed values | Omit nonpositive values, estimates, and reader fallbacks; retain a loop only when the playback consumer uses it. |
| Source archive identity | `sources[]` and source attachment | Source name, path, and hashes with scope | Do not repeat archive provenance on every SPC member. |

## SPC-specific handling

- ID666 and xID6 may both supply a field. The reader applies its documented
  precedence; keep both source blocks byte-for-byte and record parser
  diagnostics or contradictory headers in the dated conversion report.
- The reader may supply a 150-second duration fallback. Do not write that value
  as **Play Length (ms)** without positive source timing.
- Inspect every `.rsn` and enumerate its members before packaging. Keep the
  source archive outside the UAC payload. Store each SPC once; when normalizing
  its path, retain the prior name in `originalName` and record the rename in
  `transformations[]`.
- Keep source tags and unknown xID6 items in the unchanged SPC bytes. Do not
  copy the reader document, bulk native tags, raw tag blocks, diagnostics, or
  header facts into ordinary metadata.
- Keep per-member integrity hashes in the UAC hash model. Do not turn hashes,
  revision inventories, or parser facts into ordinary tag fields.

## Required checks

Validate the SPC signature, minimum size, revision byte, ID666 layout, xID6
bounds, duplicate tags, and reader diagnostics. Report textual-header/version
disagreement and mixed valid revisions separately; retain each valid **Format**
value. Confirm every source archive and extracted member is accounted for, run
`uacman inspect --verify`, then unpack and compare member paths, sizes, and
source-byte identity. Keep collection counts and exceptions in dated reports
under `Reports/`.
