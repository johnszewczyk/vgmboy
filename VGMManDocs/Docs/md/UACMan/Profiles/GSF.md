# GSF and miniGSF Profile

Apply the [UAC Base Profile](BASE-UAC-PROFILE.md). Reader structure is in
[MetaMan format layouts](../../MetaMan/format-layouts.md).

## Scope

- **Reader** — gsf in MetaManCore.
- **Source members** — One GSF music member and each declared miniGSF library
  dependency required by the source. Keep each dependency as a separate
  playable-format member or documented support member according to the UAC
  manifest contract.
- **Coverage** — PSF v0x22 tags, CRC/zlib checks, bounded library chain, and
  assembled GBA header facts; no mGBA playback.
- **Status** — Mapping documented. Fixture and package approval remain separate.

## Field Mapping

| Source Tag | UAC Tag | UAC Coded Tag | Tag Notes |
| --- | --- | --- | --- |
| GSF title | Title | `members[].metadata["Title"]` | Preserve populated root tag; filename fallback is not authored metadata. |
| GSF game | Game Title | `game.metadata["Game Title"]` | Keep separate from No-Intro Game ID. |
| GSF artist | Artist | `members[].metadata["Artist"]` | Keep track scope unless source evidence supports Album Artist. |
| GSF album | Album | `members[].metadata["Album"]` | Preserve populated root tag. |
| GSF date | Date | `members[].metadata["Date"]` | Preserve populated root tag. |
| GSF year | Year | `members[].metadata["Year"]` | Keep only when distinct from Date. |
| GSF genre | Genre | `members[].metadata["Genre"]` | Preserve populated root tag. |
| GSF comment | Comment | `members[].metadata["Comment"]` | Preserve populated root tag. |
| GSF copyright | Copyright | `members[].metadata["Copyright"]` | Preserve populated root tag. |
| GSF psfby or encodedby | Encoded By | `members[].metadata["Encoded By"]` | Preserve explicit encoding credit. |
| GSF length | Play Length (ms) | `members[].metadata["Play Length (ms)"]` | Use positive authored value. |
| GSF fade | Fade Length (ms) | `members[].metadata["Fade Length (ms)"]` | Use positive authored value. |
| GSF CRC, GBA load/header facts, and library facts | — | — | Keep as validation evidence; do not emit as descriptive tags or duplicate UAC hashes. |

## Application Behavior

- **Dependencies** — Resolve only the bounded library names in the valid root
  GSF. Keep library bytes unchanged and retain source paths in provenance.
- **Identity** — The assembled GBA header may validate payload structure. It
  does not by itself assign a DAT title root or region.
- **Hashes** — Use the UAC wrapper's embedded integrity and source identity
  records; do not copy member hashes into Songbase or fabricate hash tags.

## Format Procedures

- **Payload checks** — Require valid PSF version, CRC, zlib extents, bounded
  library chain, and acceptable GBA header evidence.
- **Missing library** — Hold the package for review; do not silently package
  only the root file as complete.

## Required Checks

- **Fixture** — Review a root GSF with its actual miniGSF chain and one
  tagless or tag-bearing variant.
- **Package** — Confirm members, provenance, package fields, and embedded
  hashes in a written UAC without altering source payload bytes.
- **Consumer** — Confirm the selected playlist/member is visible through the
  intended UAC and Songbase path.

## Reader Reference

- [GSFMetadataReader.swift](../../../../../MetaMan/Sources/MetaManCore/GSFMetadataReader.swift)
