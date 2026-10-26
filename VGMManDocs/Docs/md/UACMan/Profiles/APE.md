# Monkey's Audio Profile

Apply the [UAC Base Profile](BASE-UAC-PROFILE.md). Reader layout facts are in
[MetaMan format layouts](../../MetaMan/format-layouts.md).

## Scope

- **Reader** — ape in MetaManCore.
- **Source members** — One physical .ape audio file and its retained native tags.
  Preserve a leading ID3 block when present.
- **Coverage** — APE descriptor/header, seek table, APEv2 tags, leading ID3v2,
  and duration derived from encoded sample counts.
- **Status** — Mapping documented. Fixture and package approval remain separate.

## Field Mapping

| Source Tag | UAC Tag | UAC Coded Tag | Tag Notes |
| --- | --- | --- | --- |
| APE Title | Title | `members[].metadata["Title"]` | Keep populated native text. |
| APE Album | Album | `members[].metadata["Album"]` | Do not use Album as No-Intro Game ID. |
| APE Artist | Artist | `members[].metadata["Artist"]` | Preserve track artist. |
| APE Date | Date | `members[].metadata["Date"]` | Preserve populated value. |
| APE Year | Year | `members[].metadata["Year"]` | Keep only when distinct from Date. |
| APE Genre | Genre | `members[].metadata["Genre"]` | Preserve populated value. |
| APE Comment | Comment | `members[].metadata["Comment"]` | Preserve populated value. |
| APE Copyright | Copyright | `members[].metadata["Copyright"]` | Preserve populated value. |
| APE Encoded By | Encoded By | `members[].metadata["Encoded By"]` | Preserve populated value. |
| Encoded sample count | Play Length (ms) | `members[].metadata["Play Length (ms)"]` | Store derived timing as playback data. |
| APEv2 and ID3v2 unknown/duplicate keys | — | — | Preserve in the native member; do not flatten arbitrary tags into UAC. |

## Application Behavior

- **Tag order** — Preserve raw tag order, duplicate keys, unknown names, and
  source bytes as reader evidence. The UAC projection uses the reader's
  selected normalized values.
- **Scope** — A single encoded file is one physical member. Do not split its
  seek table or audio frames into synthetic members.
- **Identity** — Album text does not establish No-Intro identity or territory.
  Use the Museum DAT match and package Game ID workflow separately.

## Format Procedures

- **Bounds** — Validate descriptor extents, seek table, tag blocks, and sample
  counts before promotion.
- **Empty values** — Omit empty fields and retain unusual source values for
  review rather than normalizing them without evidence.

## Required Checks

- **Fixture** — Review files with APEv2, leading ID3v2, duplicate/unknown tags,
  and tagless inputs.
- **Timing** — Compare duration from source sample counts against the reader
  result.
- **Package** — Confirm member bytes and embedded wrapper hashes are intact.

## Reader Reference

- [APEMetadataReader.swift](../../../../../MetaMan/Sources/MetaManCore/APEMetadataReader.swift)
