# UAC Base Profile

Shared rules for every source-format profile. Each format profile documents
only reader-supported facts, useful fields, format-specific procedures, and
required checks.

## Metadata Rules

- **Single metadata record** — The UAC manifest is authoritative. Metadata maps
  contain direct key/value fields, never nested `{name, value}` objects.
- **Current coded paths** — Package tags use `game.metadata`; single-track
  member tags use `members[].metadata`; multi-track tags use
  `playlists[].entries[]`. Subsong `title` and `artist` are first-class fields;
  other direct track fields belong in `extraFields`. `pack.meta` and
  `track.meta` are not current manifest fields.
- **Album** — Use for a source game/album title. Do not create a Game Title
  tag. Required package identity belongs in structural `game.title`; omit a
  duplicate Album unless a consumer specifically needs it.
- **Artist scope** — Store a package-wide artist as **Album Artist** in
  `game.metadata`. Store a track-specific performer, artist, author, or
  composer as **Artist** on that logical track. Do not repeat a shared album
  artist across members; consumers may use it as fallback when track Artist is
  absent.
- **Platform** — Store the canonical name in structural `game.console`. Do not
  duplicate it as a System or Platform metadata tag; use the aliases in
  [`PLATFORMS.md`](PLATFORMS.md).
- **Direct fields** — Map each useful source fact to one Title Case field.
  MetaMan `{name, value}` records describe its reader interface, not UAC tag
  names. Do not serialize bulk native-tag maps, parser diagnostics, or reader
  dumps. Preserve source bytes unchanged.
- **Omission** — Omit empty, guessed, parser-default, and duplicate values.
  Use **Date** for a full date and **Year** when only a year is known. Omit
  **Disc Number** for a single-disc release; keep Date and Year together only
  when they represent distinct facts.
- **Member format** — `members[].format` identifies the stored member format;
  do not add a duplicate Format tag. Keep source or reader versions only when
  a format profile names a concrete need.
- **Playback data** — Use wrapper-defined loop objects and playlist-entry
  timing fields, not descriptive tags. Follow the shared
  [hash and timing policy](README.md#hash-and-timing-scope); do not duplicate
  provenance or wrapper hashes as metadata tags.
- **Set provenance** — Keep source-set authority, URLs, and collection identity
  in `sources[]`. Add a direct package field only when useful to users and
  supported by one unambiguous source.

## Profile Structure

Every format profile uses the same headings: **Scope**, **Field Mapping**,
**Format Procedures**, and **Required Checks**.

- **Scope** — Name the reader, source members, coverage, and validation status.
- **Field Mapping** — Use the shared four-column table; group it by source
  scope only when needed.
- **Format Procedures** — Use concise `- **Topic** — rule` entries only for
  behavior that does not fit in the mapping table.
- **Required Checks** — Use concise `- **Check** — evidence` entries needed
  to approve the projection.
- **Shared rules** — Link to this profile instead of repeating shared policy
  in format-specific tables.
