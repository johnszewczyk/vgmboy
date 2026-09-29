# <Format> to UAC procedure and field profile

## Reader coverage

- MetaManCore reader ID and supported extensions:
- Reader implementation and authoritative layout documentation:
- Whether a decoder/emulator is invoked:
- Recognized native fields, including repeated/ordered fields:
- Unknown fields and source bytes not decoded by the reader:
- Diagnostics and unsupported variants:

## Canonical UAC projection

| Source field | UAC location | Type and normalization | Omission/default rule |
| --- | --- | --- | --- |

Keep one canonical field per meaning. Put package-wide identity, release,
system, and source-set facts at game/package level. Put member-specific values
on the member. Keep typed format-specific extensions namespaced and distinct
from shared fields.

## Source tag projection

For each tag the reader exposes, specify one disposition: canonical UAC
field, report-only evidence, or source-only in the unchanged member. Add a
table when names or values need format-specific interpretation:

| Native tag | UAC path | JSON type | Duplicate rule | Notes |
| --- | --- | --- | --- | --- |
| | | | | |

Do not serialize the reader's `{name, value}` model or a bulk native tag map
into UAC metadata. Keep source-only tags, raw blocks, parser details, and
unselected facts in the unchanged member or conversion report. Project only
populated, useful, source-backed values as direct canonical UAC fields; keep
their names and types consistent with the shared contract. The exact member
bytes remain authoritative for original ordering, duplicates, encoding, and
undecoded data. Store projected and newly authored tag names directly in
Title Case. Do not keep a lowercase or camelCase duplicate for the same
concept. Structural UAC property names retain the exact spelling in the UAC
contract; those properties are not free-form tags.

State how reader-generated fallbacks differ from values found in the source.
Do not promote a filename, default duration, display label, or parser guess as
a native tag.

## Format tag and version

Use the single direct member tag **Format** for the contained source format.
When the format defines a version, combine the format name and version in one
value (for example, `SPC v.30`) on every applicable member, including uniform
versions. Do not infer a version when a header is missing, malformed, or
unreadable. Record valid member variation and report its distribution. Follow
the format/set review rule while retaining every valid member tag. Do not add
a duplicate Sub-Container Version tag or a package-level version inventory.
The manifest's structural `member.format` identifies the UAC member encoding
and is distinct from this user-facing source-format tag.

## Source preservation and provenance

- State whether the original member bytes are retained unchanged.
- Identify source packages/sidecars that remain outside UAC.
- Record exact set name and URL at package/source level.
- Define the source-file hash catalog and member/playable hash scopes. Use one
  four-algorithm list for one source file; add multiple source-state catalogs
  only when the source genuinely includes multiple distinct files or states.
- Record original member names and any path-only transformations.
- Explain which decoded values are evidence only, not canonical metadata.

## Hash and version profile

| Scope | Algorithms | Profile | Meaning |
| --- | --- | --- | --- |
| Source package | | | |
| Initial source state | | | |
| Playable member | | | |

State the Format tag and how package revision conflicts are
reported without duplicating version values into package metadata. Explain the
distinction between a package containing multiple native format revisions
and conflicting version representations within one member.

## Set-quality audit

Specify checks for malformed headers/chunks, parser diagnostics, unsupported
variants, missing and duplicate members, duplicate streams, cross-title or
cross-version matches, and package/set identity conflicts. Define which
findings require review and where the flag is stored. Do not invent manifest
fields unsupported by the UAC contract.

## Required validation

- Full UAC payload verification and manifest readback.
- Expected member path, byte-size, role, and content-hash inventory.
- Required per-member and per-source checksum coverage.
- Database/catalog reconciliation and stale-path handling.
- A dated format or collection report in `Reports/`.
