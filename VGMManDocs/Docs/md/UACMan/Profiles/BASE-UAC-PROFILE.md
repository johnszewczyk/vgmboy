# UAC Base Profile

Shared rules for every source-format profile. Each format profile documents
only reader-supported facts, useful fields, format-specific procedures, and
required checks.

These profiles are human-readable working notes for people and agents. They
are not a mechanical UACMan configuration, automatic tag mapper, or validator;
apply the documented rules explicitly and record evidence in the set report.
They define **input rules** for how source information should be interpreted
and promoted into UAC metadata. They are not output reports: observed coverage,
actual changes, exceptions, and verification results belong in AudioMan's
dashboard reports, preferably in the affected set's per-console report, with
the per-set ledger recording operations and checkpoints.

## Metadata Rules

- **Single metadata record** — The UAC manifest is authoritative. Metadata maps
  contain direct key/value fields, never nested `{name, value}` objects.
- **Current coded paths** — Package tags use `game.metadata`; single-track
  member tags use `members[].metadata`; multi-track tags use
  `playlists[].entries[]`. Subsong `title` and `artist` are first-class fields;
  other direct track fields belong in `extraFields`. `pack.meta` and
  `track.meta` are not current manifest fields.
- **Album** — Use the source-format profile's mapping for game or release
  names. For SPC, the source **Game** field maps to track **Album**; keep
  package identity in structural `game.title` and any confirmed **Game ID**
  separately.
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
- **Text documents** — Each format or set profile states whether source text
  is mined into existing metadata/playback fields, retained as a package
  document, or omitted after its useful information is represented elsewhere.
  Never silently discard a source document. When a primary human-readable
  notes document is retained, use the package member name `meta.txt` and
  reference it through `game.metadata.documents`; preserve the source basename
  and any path rename in the member/source provenance. Keep the document bytes
  unchanged. Do not invent tags just to avoid retaining useful narrative notes.
- **Title Snap** — When a set workflow positively identifies an exact game or
  release image, store one package-level **Title Snap** field whose value is
  the relative path to a bundled PNG asset (for example,
  `art/title-snap.png`). Include the image as a `role: asset` member with the
  normal UAC member-integrity records, and record its source and attachment
  operation in package provenance. Do not duplicate this tag across tracks or
  leave it blank. If the exact image is unavailable, region/release identity
  conflicts, or an existing snap differs, leave the package unchanged and
  route the case to the set report for review; do not substitute a nearby image.
- **Omission** — Omit empty, guessed, parser-default, and duplicate values.
  Use **Date** for a full date and **Year** when only a year is known. Omit
  **Disc Number** for a single-disc release; keep Date and Year together only
  when they represent distinct facts.
- **Format** — A UAC package has one playable format; do not mix playable
  formats in one package. Where the source format profile calls for a surfaced
  format/version, store it as track **Format** (for example, `SPC v.30`). Do
  not add a redundant package-level generic **Format** tag.
- **Format check** — Confirm all playable members belong to the package's
  structural format; reject a package that mixes formats.
- **Status** — Add package-level `Status` only for a confirmed issue requiring
  a re-rip. Its non-empty value is an array containing one or more exact
  labels: `Mixed Versions`, `Incomplete`, or `Corrupt`. Omit the tag when no
  issue is declared; never write `Good`. `Corrupt` requires evidence of a
  critical known defect, and the affected material stays retained outside a
  clean canonical package. `Mixed Versions` packages may remain in a canonical
  set during review, but the tag still marks them for re-rip. Keep detailed
  findings and reasons in the per-set dashboard report, not in extra UAC tags.
- **Playback data** — Use wrapper-defined loop objects and playlist-entry
  timing fields, not descriptive tags. Follow the shared
  [hash and timing policy](README.md#hash-and-timing-scope). Source-archive
  hashes may be surfaced on tracks when a set profile says they identify the
  distribution source; member **Stream Hashes** identify each playable file.
- **Set identity** — When source evidence identifies one set, surface **Set
  Name** and **Set URL** once at package scope. Add
  **Set Legacy URL**, **Set Archive URL**, or **Set Date** when applicable.
  These direct fields help users compare and group packages; `sources[]`
  remains the detailed provenance authority. Omit a projection when sources
  conflict or the value is not trustworthy.

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
