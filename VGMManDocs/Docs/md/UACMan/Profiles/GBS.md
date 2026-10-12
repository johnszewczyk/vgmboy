# Game Boy Sound System · GBS Profile

Apply the [UAC Base Profile](BASE-UAC-PROFILE.md) and
[Compact Pre-Disc Native Procedure](PRE-DISC-NATIVE.md). GBS is a compact
Game Boy music container; one physical `.gbs` file may expose several logical
tracks. MetaMan reads its fixed header and can use NEZplug extended-M3U
sidecars. See [`MetaMan/format-layouts.md`](../../MetaMan/format-layouts.md).
The native header fields and version byte follow the
[GBS format definition](https://github.com/mmitch/gbsplay/blob/master/gbsformat.txt).

## Scope

- **Metadata reader** — MetaMan's `gbs` reader parses the fixed GBS header and
  optional extended-M3U rows. The current VGMBoy playback registry supports
  `.gbs` through libgme. Neither current application reader supports `.gbr`,
  `.mgb`, or general `.gb` ROMs.
- **Source members** — `.gbs`; optional companion `.m3u` files.
- **Coverage** — GBS header game, artist, and comment fields; M3U track rows
  and recognized `# @KEY value` comments.
- **Status** — Reader, writer, and consumer mappings are aligned in code.
  Apply this profile per package: inspect every associated M3U, hold conflicting
  rows for review, then verify the generated playlist through UACMan,
  ScanSong, and Songbase. Parser support alone does not establish that a source
  set is coherent or canonical. MetaMan converts
  fractional play, loop, and fade times to integer milliseconds, and reads
  NEZplug's loop-duration, loop-start, and whole-play loop forms. When rows
  conflict, ambiguous fields are omitted and diagnosed. Retain the original
  M3U and keep conflicting projections held for review.

## Field Mapping

| Source Tag | UAC Tag | UAC Coded Tag | Tag Notes |
| --- | --- | --- | --- |
| GBS header `game` | Album | `game.metadata["Album"]` | One nonempty, shared value for the physical GBS file. Do not substitute a filename or an inferred DAT title. |
| GBS header `artist` | Album Artist | `game.metadata["Album Artist"]` | Shared source value; do not duplicate it as track Artist. |
| GBS header copyright string (MetaMan exposes `comment`) | Copyright | `game.metadata["Copyright"]` | This fixed header slot is the format's copyright field; preserve its populated value as written. |
| M3U `# @TITLE value` | Album | `game.metadata["Album"]` | Use only when all applicable rows agree and the value agrees with a populated header; otherwise retain the header and route the conflict to review. |
| M3U `# @ARTIST value` | Album Artist | `game.metadata["Album Artist"]` | Use only when the value is shared and unambiguous; if it conflicts with a populated header, retain the header and report the conflict. |
| M3U `# @DATE value` | Date | `game.metadata["Date"]` | Keep the source value; do not infer a date from a filename or composite track title. |
| M3U `# @YEAR value` | Year | `game.metadata["Year"]` | Preserve separately from Date when both are present. |
| M3U `# @COMPOSER value` | Composer | `game.metadata["Composer"]` | Promote only a populated, unambiguous shared value. |
| M3U `# @RIPPER value` | Dumper | `game.metadata["Dumper"]` | The source uses Ripper; UAC uses the established Dumper field. |
| M3U `# @TAGGER value` | Tagger | `game.metadata["Tagger"]` | Promote only a populated, unambiguous shared value. |
| M3U `# @DEVELOPER value` | Developer | `game.metadata["Developer"]` | Promote only when present and unambiguous. |
| M3U `# @PUBLISHER value` | Publisher | `game.metadata["Publisher"]` | Promote only when present and unambiguous. |
| M3U `# @GENRE value` | Genre | `game.metadata["Genre"]` | Promote only when present and unambiguous. |
| M3U `# @COPYRIGHT value` | Copyright | `game.metadata["Copyright"]` | Compare with the GBS header comment; keep a conflicting value in the attached M3U for review. |
| M3U `::GBS,index,title,...` title | Title | `playlists[].entries[].title` | Source track title, retained as written. Do not split embedded composer, game, publisher, or copyright text out of the title. |
| M3U source index and row order | Playlist `trackIndex` and entry order | `playlists[].entries[].trackIndex` | GBS indexes are zero-based, including hexadecimal indexes. Keep entries in the M3U's row order; do not sort them by source index or create a second Track Number tag. |
| M3U row, source path, and authored values | M3U | `playlists[].entries[].extraFields["M3U"]` | Keep the tag name exactly `M3U`; do not split or title-case the acronym. Keep the exact raw row, source M3U path, populated raw timing/count fields, and positive millisecond projections together in one nested JSON value. Do not expose separate M3U timing tags or duplicate raw fields at entry level. |
| M3U time, loop, fade columns | M3U timing properties | `playlists[].entries[].extraFields["M3U"]` | Convert fractional final time components to integer milliseconds. A loop-start value marked with `-` maps to Intro Length; do not infer a loop duration from it. A bare `-` sets Loop Length equal to Play Length. Missing or invalid times stay absent. Keep raw strings and repeat counts in the nested value and the original M3U attachment byte-exact. |
| GBS header version byte | Format | `playlists[].entries[].extraFields["Format"]` | Use `GBS v.<version>` on every logical track, for example `GBS v.1`. Read the byte from that physical member; never normalize versions. |
| GBS member filename stem beginning with `DMG-` or `CGB-` | Catalog | `game.metadata["Catalog"]` | Preserve the exact stem, including prefix and suffix (for example, `DMG-AIPE-USA`). Set it once at package scope when all included GBS members share one code. Do not infer it from a title, No-Intro ID, or region. Different codes in one package require review. |

## Application Behavior

- **MetaMan** reads the fixed GBS header and matching NEZplug extended-M3U
  rows. It preserves the header game/artist/copyright fields separately from
  M3U comments, retains source timing strings, and parses fractional
  milliseconds. One-row M3Us are per-track annotations; only multi-row M3Us
  define competing queue orders. When a queue exists, its row order controls
  playlist order. If only annotations exist, source GBS index controls order.
  Shared comments are resolved by track index, so absent comments in a sidecar
  do not create false conflicts. Conflicting populated comments or duplicate
  row values remain diagnosed and unpromoted.
- **UACMan writer** places shared header identity in package `game.metadata`
  and `Title`, `Format`, and the single nested `M3U` value on each logical
  playlist entry. A one-track GBS still gets an explicit subsong entry. The
  Tag Analyzer reads and edits first-class playlist titles and entry
  `extraFields`, including the nested M3U JSON, in their original playlist
  entry scope.
- **MetaMan UAC reader and ScanSong** expand each mapped subsong to one logical
  track row. They expose `Format` and nested `M3U` with the track, and convert
  the nested positive millisecond values back to the playback timing API. A
  missing timing value remains missing.
- **AudioMan Songbase** retains the ordered source playlist JSON in
  `uac_package_manifests.playlists_json` and indexes first-class title plus
  per-entry metadata under `archive_metadata_fields` as
  `uac-playlist-entry`. This is a manifest projection; ingestion does not
  rehash the GBS payload or count one physical GBS member once per subsong.
- **Dashboard reports** continue to record per-set results, discrepancies,
  and conversion checks. This profile only defines input and application
  mapping rules.

## Format Procedures

- **Platform identity** — Set structural `game.console` from a verified source
  system or canonical database match. GBS alone does not distinguish Game Boy
  from Game Boy Color; the version byte is not a platform identifier. Use the
  exact canonical aliases in
  [`PLATFORMS.md`](PLATFORMS.md); hold Super Game Boy labels when their
  platform meaning is unclear. Do not add a repeated Platform tag.
- **Physical file and subsongs** — Store each source `.gbs` once and point
  ordered playlist entries at it. Keep a one-track GBS as an explicit
  playlist entry too. Hash the physical member once, not once per subsong.
- **Identity and platform** — A GBS signature identifies the container, not
  whether the music belongs to Game Boy or Game Boy Color. Use source
  platform evidence and the format-agnostic No-Intro identity workflow; hold
  titles that resolve differently across the GB and GBC DATs for review. When
  the game root is positive, put the canonical DAT title root string in
  package **Game ID**; this does not select a region or revision. Keep numeric
  DAT IDs in AudioMan only.
- **Settled-package promotion** — A package with one valid GBS member, no
  unresolved M3U/title/timing conflict, no header/version exception, and no
  unexplained companion file can move to UAC without waiting for unrelated
  review cases. Preserve its source package and member; project populated
  native header values to Album, Album Artist, and Copyright; add one logical
  playlist entry per declared track with `Format` on every entry; and retain
  the four playable-payload hashes for the physical GBS. If no M3U supplies a
  track title or timing, leave those fields absent. Do not add a `Game ID`
  until the canonical title root has positive No-Intro evidence. Keep each
  unresolved package as its own case page in the AudioMan set report.
- **Format version** — Read version byte `0x03` for every physical GBS and
  surface it in each track's **Format** field. A set can contain v1, v2, or
  v4 files; do not flatten them to one version. Report multiple versions
  within a game/package and hold the affected package for review.
- **Catalog and subtrack names** — Read `Catalog` only from a playable GBS
  member filename whose stem begins `DMG-` or `CGB-`; retain the complete stem
  verbatim. A single shared code belongs at package scope. Differing codes in
  one package require review. Keep each M3U-authored track title exactly as
  written, including numbered or generic titles such as `BGM #01` and numeric
  labels. Do not derive a title from a sidecar filename or invent a better
  title. When an alternate source for the same GBS payload supplies different
  subtrack names, preserve the source distinction and report it for review
  rather than silently replacing or combining the lists.
- **GBS header fields** — Validate the 112-byte fixed header, `GBS` signature,
  nonzero version and track count, and the declared first-track index. Keep
  load/init/play addresses and timer bytes as validation evidence only; do
  not promote them to user-facing tags. Treat `?`, `<?>`, and `< ? >` header
  placeholders as absent so they do not block a populated M3U value.
- **M3U files** — Preserve every source M3U byte-for-byte as a package
  attachment, including multiple M3Us that refer to the same GBS. Their rows
  can carry track names and playback timing, so they are not disposable
  generated queues. Preserve original names and paths in source provenance.
  A row reference may omit the final `.gbs` suffix; resolve it to an exact,
  case-insensitive member stem only when that identifies one physical GBS.
  Hold a source package with colliding member stems for review.
  Store each applicable row in one Title Case nested `M3U` JSON value on its
  playlist entry. Include `Source Path`, `Raw Row`, populated raw `Play Time`,
  `Loop`, `Loop Start`, `Fade`, and `Loop Count`, plus positive
  `Play Length (ms)`, `Intro Length (ms)`, `Loop Length (ms)`, and
  `Fade Length (ms)` projections. Keep the first-class entry `title` and
  wrapper timing projections usable by playback; do not flatten the M3U fields
  into separate entry tags. When one M3U applies to the package playlist,
  `originalMemberPath` identifies it and `Source Path` is omitted from each
  row. When several M3Us apply, per-entry `Source Path` disambiguates them.
- **M3U row conflicts** — Compare all rows for the same GBS member and
  zero-based index. If titles, comments, or timings disagree, retain the
  competing source rows and route the track/package to its own case review.
  Do not silently select the richest row, merge rows, or treat a second title
  as a duplicate without evidence. A one-row sidecar annotates its referenced
  track and does not assert queue order. Preserve the order from the authored
  multi-row queue; hold repeated indexes or genuinely different multi-row
  queue orders for review. Capturing an authored loop value records what the
  source says, not that listening has confirmed its correctness. Leave that
  judgment open for listening where needed; never invent a loop value.
- **Cross-format loop evidence** — A VGMRIPS VGM may corroborate GBS loop data
  when its GD3 `Comment` identifies the exact GBS source filename and
  zero-based subsong index, and the track title also aligns. Compare loop
  presence and loop samples with the authored M3U `Play Length`, `Loop`, and
  `Loop Start` values using the [VGM profile](VGM.md). A game-title match alone
  is only a candidate. Treat the VGM as separate captured evidence: never copy
  its loop marker into GBS metadata, and leave missing GBS loop values absent.
  Record mismatches or unavailable source provenance in the per-set report for
  review.
- **Timing** — M3U timing is playback data attached to the logical track.
  MetaMan converts play, loop, and fade values, including a fractional final
  component with up to millisecond precision, to integer milliseconds.
  Preserve both those projections and their authored source strings under the
  nested `M3U` value. A trailing hyphen on the loop field marks a loop start;
  a bare hyphen means the loop duration equals play length. Invalid or absent
  timing stays absent; GBS header-only tracks have no known duration and must
  not receive a 150-second fallback.
- **Composite titles and comments** — Keep a composite M3U title as one Title
  value. Promote a recognized, populated `# @KEY` value only through an
  explicit useful-field mapping with canonical Title Case tag names. Current
  shared mappings are Title, Artist, Date, Year, Composer, Ripper, Tagger,
  Developer, Publisher, Genre, and Copyright. Do not surface raw lower-case
  source keys, empty values, placeholders, freeform comments, unknown keys, or
  parser diagnostics as UAC tags; retain the original M3U attachment.
- **Related but separate members** — These are not GBS tracks and must not be
  folded into a GBS package or counted as GBS duplicates:

  | Member | Identification | Handling |
  | --- | --- | --- |
  | `.gbr` | Older Game Boy music-dump format (`GBRF` signature) | Separate format and review; current VGMBoy/MetaMan readers do not support it. The independent [gbsplay project](https://github.com/mmitch/gbsplay) lists GBR support. |
  | `.mgb` | Paragon 5 GameBoy Tracker module (`GameBoy Music Module` marker) | Separate tracker format and review; current VGMBoy/MetaMan readers do not support it. See [Paragon 5 tracker files](https://gbdev.gg8.se/files/musictools/Paragon5/). |
  | `.gb` | Raw Game Boy ROM image | ROM, not a GBS music container; route to ROM review. gbsplay supports only a subset as music, which is not support in our current reader. |

  Validate content signatures, not suffixes. A `.gbs`-named member that lacks
  the `GBS` signature (including a ROM image) is an extension/content
  mismatch for review, not a playable GBS track. Preserve the source archive
  and report the member instead of silently dropping it.
- **Hashes** — Apply the four compact pre-disc hashes to each physical GBS
  stream under the shared procedure. Keep these as UAC integrity/source
  identity records, not invented tag keys.

## Required Checks

- **Header and version** — Check every physical `.gbs` signature, header
  length, version byte, declared track count, first index, and nonempty
  identity fields. Record version counts and identify mixed-version games.
- **Format boundary** — Inventory `.gbr`, `.mgb`, and `.gb` members separately;
  confirm they are not counted as GBS tracks or silently discarded. Treat a
  mismatched `.gbs` suffix as a review item.
- **Playlist mapping** — Resolve every M3U row to one member and an in-range
  zero-based track index. Preserve order and raw row text. Treat one-row
  files as track annotations. Hold repeated indexes, out-of-range references,
  or conflicting multi-row queue orders for review; retain all sidecars and
  report missing, duplicate, or conflicting references.
- **Timing fidelity** — Compare source timing strings with UAC playlist
  entries. Confirm fractional seconds and both loop syntaxes convert without
  truncation, conflicting values are omitted, repeat counts remain available
  in the source M3U attachment, and absent values stay absent without a
  150-second fallback.
- **Tag scope** — Confirm Album and Album Artist are shared only when their
  source values agree, track titles remain attached to the correct index, and
  no empty, inferred, or diagnostic tags were added.
- **UAC review** — Verify Format and M3U are visible on each logical track,
  package metadata stays at package scope, hashes are visible
  in Stream Hashes, and source M3Us remain available as package attachments.
  The Tag Analyzer's playable-track count and playlist-entry rows expose
  subsong metadata; the physical-member Tracks grid can show one GBS file for
  many logical subsongs. Keep affected conversions held until competing M3U
  rows are reviewed.
