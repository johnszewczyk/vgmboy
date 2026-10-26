# QSF and miniQSF Profile

Apply the [UAC Base Profile](BASE-UAC-PROFILE.md). Reader structure is in
[MetaMan format layouts](../../MetaMan/format-layouts.md).

## Scope

- **Reader** — qsf in MetaManCore.
- **Source members** — One root QSF and each declared QSFLib dependency required by
  the source.
- **Coverage** — PSF v0x41 tags, CRC/zlib and QSound block bounds, and declared
  library references. The reader does not start the QSound playback core.
- **Status** — Mapping documented. Fixture and package approval remain separate.

## Field Mapping

| Source Tag | UAC Tag | UAC Coded Tag | Tag Notes |
| --- | --- | --- | --- |
| QSF title | Title | `members[].metadata["Title"]` | Preserve populated root value; filename fallback is not authored metadata. |
| QSF game | Game Title | `game.metadata["Game Title"]` | Keep distinct from DAT Game ID. |
| QSF artist | Artist | `members[].metadata["Artist"]` | Promote populated root tag. |
| QSF album | Album | `members[].metadata["Album"]` | Preserve populated root tag. |
| QSF date | Date | `members[].metadata["Date"]` | Preserve populated root tag. |
| QSF year | Year | `members[].metadata["Year"]` | Keep only when distinct from Date. |
| QSF genre | Genre | `members[].metadata["Genre"]` | Preserve populated root tag. |
| QSF comment | Comment | `members[].metadata["Comment"]` | Preserve populated root tag. |
| QSF copyright | Copyright | `members[].metadata["Copyright"]` | Preserve populated root tag. |
| QSF psfby or encodedby | Encoded By | `members[].metadata["Encoded By"]` | Keep explicit source credit. |
| QSF length | Play Length (ms) | `members[].metadata["Play Length (ms)"]` | Convert positive authored seconds to milliseconds. |
| QSF fade | Fade Length (ms) | `members[].metadata["Fade Length (ms)"]` | Convert positive authored seconds to milliseconds. |
| QSF blocks and dependency names | — | — | Preserve as source/container evidence, not user tags. |

## Application Behavior

- **Dependencies** — Resolve only declared QSFLib names, within the reader's
  bounded search scope. Preserve all dependency bytes and provenance.
- **Identity** — Capcom QSound is the reader's system description, not a
  substitute for a verified game/platform identity.
- **Hashes** — Retain wrapper-generated member and source hashes in the UAC.
  Songbase and Museum must not store duplicate UAC hashes.

## Format Procedures

- **Validation** — Require the expected PSF version, valid CRC and zlib
  extents, valid QSound block bounds, and a complete required library chain.
- **Missing dependencies** — Keep unresolved or conflicting chains in Review.

## Required Checks

- **Fixture** — Review root QSF files with and without dependencies and
  populated or absent tag footers.
- **Package** — Confirm root/dependency membership, source provenance, visible
  fields, and wrapper integrity after packaging.
- **Consumer** — Confirm the manifest projects as intended through UACMan and
  the relevant catalog/player path.

## Reader Reference

- [QSFMetadataReader.swift](../../../../../MetaMan/Sources/MetaManCore/QSFMetadataReader.swift)
