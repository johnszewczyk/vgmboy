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
- **Nested source metadata** — Use a nested JSON value only when a format
  profile explicitly names a source structure that belongs together, such as
  the authored row and timing fields under `M3U`. Do not flatten that record
  into a family of redundant surface tags.
- **Album** — Use the source-format profile's mapping for game or release
  names. For SPC, the source **Game** field maps to track **Album**; keep
  package identity in structural `game.title` and the package-level **Game
  ID** separately when No-Intro positively identifies the game.
- **No-Intro Game ID** — Store the canonical No-Intro game-root title as one
  package-level string in `game.metadata["Game ID"]`. Use the DAT's displayed
  title root, without its region, revision, or dump-status suffix. Keep
  No-Intro's numeric `dat_id` only in AudioMan's identity database; do not put
  it in UAC metadata, `game.canonicalIDs`, or
  `variants[].canonicalReleaseIDs`. A known title root does not establish
  region or revision; keep **Region** separate and omit it when unknown. If a
  title is not represented in No-Intro or its root remains ambiguous, omit
  **Game ID** and leave the identity for review.
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
- **Snap-based identity evidence** — A title-snap collection may help identify
  an otherwise unnamed package. Match the candidate image by its visible title
  and recognizable screen, then record the source pack and match evidence in
  the identity review. A filename match or generic artwork alone does not
  establish a specific region or release; keep those fields unknown unless the
  image or another source resolves them.
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
  clean canonical package. A positively identified `Mixed Versions` package
  may be integrated into its final set path with its Status tag and observed
  per-track Format values intact; it remains a re-rip candidate. Keep detailed
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

## Application Behavior

- **MetaMan input** — A format profile may promote only facts its named reader
  actually returns. Preserve native source bytes and attached sidecars so
  values outside the current mapping remain recoverable.
- **UACMan writer** — The mapping table defines the output manifest path.
  Package fields go in `game.metadata`; single-member fields go in
  `members[].metadata`; logical subsong fields go in the playlist entry's
  first-class fields or `extraFields`, as specified by the profile. Profiles
  are human instructions, not automatic mapping configuration.
- **UACMan review** — The Tag Analyzer must show and edit package, member, and
  playlist-entry fields in their true storage scope. Nested JSON remains one
  field and is edited as JSON; the UI must not flatten it or make it invisible.
- **MetaMan UAC reader and ScanSong** — Read fields from the manifest scope
  where they are stored. Expand subsong playlist entries into logical track
  rows, expose their track metadata, and project wrapper timing into the
  playback timing interface without inventing absent values.
- **AudioMan Songbase** — Keep the complete UAC manifest and ordered playlist
  JSON for exact retrieval. Index first-class playlist titles and entry
  `extraFields` separately from physical member rows. Songbase ingestion reads
  embedded hashes and does not rehash contained payloads.
- **Dashboard** — Record observed set coverage, conflicts, failures, and
  verification in per-set reports. A profile describes the input mapping and
  app contract; it is not a report of completed output.

## Profile Structure

Every format profile uses the same headings: **Scope**, **Field Mapping**,
**Format Procedures**, and **Required Checks**. Add an **Application
Behavior** section when that format has a specific producer, UI, playback, or
database nuance beyond the shared contract above.

- **Scope** — Name the reader, source members, coverage, and validation status.
- **Field Mapping** — Use the shared four-column table; group it by source
  scope only when needed.
- **Application Behavior** — State any format-specific exception to the
  shared application contract above. Document only the applications that
  participate in the path, and distinguish stored source data from projected
  display/query fields.
- **Format Procedures** — Use concise `- **Topic** — rule` entries only for
  behavior that does not fit in the mapping table.
- **Required Checks** — Use concise `- **Check** — evidence` entries needed
  to approve the projection.
- **Shared rules** — Link to this profile instead of repeating shared policy
  in format-specific tables.
