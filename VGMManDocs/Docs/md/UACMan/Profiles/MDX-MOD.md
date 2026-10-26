# X68000 MDX and ProTracker MOD Profile

Apply the [UAC Base Profile](BASE-UAC-PROFILE.md). Exact reader structures are
documented in [MetaMan format layouts](../../MetaMan/format-layouts.md).

## Scope

- **Readers** — mdx and mod-protracker in MetaManCore.
- **Source members** — One .mdx or recognized 31-sample .mod file, plus a
  referenced .pdx companion when present.
- **Coverage** — MDX reads Shift-JIS title/PDX reference and times supported
  uncompressed bodies; MOD claims recognized 31-sample ProTracker-family
  headers. Unsupported MOD dialects remain outside this reader.
- **Status** — Mapping documented. Fixture and package approval remain separate.

## Field Mapping

| Source Tag | UAC Tag | UAC Coded Tag | Tag Notes |
| --- | --- | --- | --- |
| MDX Shift-JIS title | Title | `members[].metadata["Title"]` | Preserve decoded title; do not infer game or artist. |
| MDX PDX name | PDX Dependency | `members[].metadata["PDX Dependency"]` | Keep the reference as a string; do not claim the companion exists unless present. |
| MDX supported MML timing | Play Length (ms) | `members[].metadata["Play Length (ms)"]` | Available only for supported uncompressed bodies. |
| MOD 31-sample header title | Title | `members[].metadata["Title"]` | Preserve populated title. |
| MOD SAMPLE_nn_TITLE | — | — | Preserve in the source member; sample labels are not game or track titles. |

## Application Behavior

- **Platform identity** — MDX is Sharp X68000; MOD is Commodore Amiga. Use the
  canonical value in structural game.console when independently identified.
- **Timing** — Do not replace unavailable MDX timing with a guessed duration.
  MOD reader facts do not supply authored track timing.
- **Dependencies** — PDX is not playable audio. Keep it as a separate member
  and preserve the source relationship in provenance.

## Format Procedures

- **MDX compression** — LZX-compressed bodies have no MetaMan timing projection.
- **MOD dialects** — The direct reader claims only recognized ProTracker-family
  31-sample layouts. Leave old 15-sample and unidentified dialects on their
  existing route.

## Required Checks

- **Recognition** — Confirm the reader ID, extension, signature or supported
  header dialect, and source bounds.
- **PDX** — Verify any dependency path against the actual source package.
- **Projection** — Review member title and any timing in a representative
  UAC; do not treat sample labels or parser facts as metadata tags.

## Reader References

- [MDXMetadataReader.swift](../../../../../MetaMan/Sources/MetaManCore/MDXMetadataReader.swift)
- [MODMetadataReader.swift](../../../../../MetaMan/Sources/MetaManCore/MODMetadataReader.swift)
- [MDXSequenceTimingReader.swift](../../../../../MetaMan/Sources/MetaManCore/MDXSequenceTimingReader.swift)
