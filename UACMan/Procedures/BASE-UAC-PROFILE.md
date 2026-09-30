# UAC Base Profile

This is the shared rule set for source-format profiles. A format profile records
only reader-specific facts and useful fields that its source can support.

## Metadata fields

- The manifest is the one UAC metadata record. Tags are direct key/value
  fields in metadata maps, not nested `{name, value}` objects.
- Use the current manifest paths in **UAC Coded Tag**: package tags live in
  `game.metadata`, single-track member tags in `members[].metadata`, and
  per-track tags for a multi-track member in `playlists[].entries[]`.
  Subsong entries use their first-class `title` and `artist` fields; other
  direct track fields belong in `extraFields`. `pack.meta` and `track.meta`
  are not fields in the current UAC manifest.
- Use **Album** for a source game/album title. Do not create a **Game Title**
  tag. Keep required package identity in structural `game.title`; it is not a
  metadata tag. If Album would exactly repeat `game.title`, do not store a
  second copy unless a consumer specifically requires an Album field.
- A package-wide source artist maps to **Album Artist** in
  `game.metadata["Album Artist"]`. A track-specific performer, artist, author,
  or composer maps to **Artist** on that logical track. Do not copy a shared
  album artist onto every member. When a track has no **Artist**, consumers may
  display the package's **Album Artist** as its artist fallback.
- Store the canonical platform name in structural `game.console`. Do not add a
  duplicate **System** or **Platform** metadata tag. Source aliases are listed
  in [`PLATFORMS.md`](PLATFORMS.md).
- Map each useful source fact to one direct, Title Case field. MetaMan's
  `{name, value}` records describe its reader interface; they are not UAC tag
  names. Do not serialize bulk native-tag maps, parser diagnostics, or reader
  dumps. Preserve source bytes unchanged.
- Omit empty, guessed, parser-default, and duplicate values across all
  profiles. Use **Date** for a full date and **Year** when only a year is
  known. Omit **Disc Number** for a single-disc release. Keep Date and Year
  together only when they describe distinct facts, such as release date and
  copyright year.
- `members[].format` identifies the format of the stored member. Do not add a
  **Format** metadata tag that repeats that value. Keep source/reader versions
  only when a format profile identifies a concrete user or consumer need.
- Keep playback structure in the wrapper-defined loop object and playlist
  entry timing fields, not in descriptive tags. Follow the shared
  [hash and timing policy](README.md#hash-and-timing-scope). Do not duplicate
  source provenance or wrapper hashes as metadata tags.
- Keep source-set authority, URLs, and collection identity in `sources[]`;
  project a direct package field only when it is useful to users and supported
  by one unambiguous source.

## Profile shape

Keep each format profile to four parts:

1. Reader and source scope, with links to the owning implementation and
   authoritative layout documentation.
2. Mapping tables grouped by source scope when that makes the mapping clearer:
   source tag, canonical UAC tag, current coded path, and any format-specific
   rule.
3. Only format-specific procedures that cannot be expressed in the tables.
4. The minimal fixture and package checks needed to approve the mapping.

Shared rules stay here and are linked rather than repeated in every table.
