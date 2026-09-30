# UAC Base Profile

This is the shared rule set for format profiles. A format profile only records
facts unique to its reader and the fields that reader can support.

## Mechanical mapping rules

- The UAC manifest is the package record. Direct package tags live in
  `pack.metadata`; direct track tags live in `track.metadata`. They are not a
  second data store or nested `{name, value}` objects.
- UACMan's GUI reads and edits manifests only. MetaManCore reads source-member
  formats during explicit package creation and conversion workflows.
- Put a package fact on `pack.metadata` once and a track fact on
  `track.metadata`. Store one canonical package-level **Platform** at
  `game.platform` from [`PLATFORMS.md`](PLATFORMS.md); do not repeat it as a
  field on individual tracks.
- Map each useful source fact to one direct, Title Case field. Do not serialize
  MetaMan's `{name, value}` reader records, bulk native-tag maps, diagnostics,
  or format-reader dumps as tags. Keep source bytes unchanged.
- Omit empty, guessed, parser-default, and duplicate fields. Use **Date** when
  a full date is known; use **Year** when only the year is known. Keep both
  only when they describe distinct facts, such as a release date and copyright
  year.
- Use the track's structural format field for the contained source format. Add
  a direct **Format** tag only when a source-defined version or variant is
  useful to UAC users. Do not duplicate `track.format` as a tag.
- Keep playback structure such as `metadata.loop`, source provenance, and
  wrapper hashes in their contract-defined fields. Do not copy them into
  ordinary tag fields or create duplicate checksum tables. Follow the shared
  [hash and timing policy](README.md#hash-and-timing-scope) and the wrapper
  contract.
- Put parser findings and unresolved mappings in a dated report under
  `Reports/`; do not add collection counts or one-off findings to an evergreen
  format profile.

## Profile shape

Keep each format profile to four parts:

1. Reader and source scope, with links to the owning implementation and
   authoritative layout documentation.
2. One mapping table: displayed source tag, canonical UAC tag, UAC coded tag
   path, and tag notes.
3. Only format-specific exceptions that cannot be expressed in the table.
4. The minimal fixture and package checks needed to approve the mapping.

The format profile template provides this structure. Shared rules stay here
and are linked rather than copied into each profile.
