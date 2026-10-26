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
- **Coverage** — GBS header Game Title, Author, and Copyright fields; M3U
  track rows and recognized `# @KEY value` comments.
- **Status** — Reader/writer mapping and pack/unpack fixtures passed on
  2026-10-26 for supported header values, ordered subsongs, and byte-exact
  source preservation. Per-set playlist and consumer review remains required.
  The GBS header does not
  declare a text encoding; only ASCII header strings are promoted. Non-ASCII
  fields remain in the unchanged GBS member and are routed to the
  header-encoding uncertainty bucket. The
  [NEZplug extended-M3U syntax](https://github.com/BouKiCHi/nezplay/blob/master/in_nez.txt#L948-L968)
  defines `::KSS`
  and `::GBS` as distinct type markers. Some JoshW sidecars use `::KSS` while
  naming members whose extension and validated signature are GBS; these are
  source-side type-marker mismatches, and the current GBS reader ignores
  them. Preserve the source rows and leave them out of projected playlist
  metadata until an explicit recovery policy is approved. Apply this profile per package:
  inspect every associated M3U, compare a master queue with per-track
  sidecars, hold conflicting or unprojected rows, then verify the generated
  playlist through UACMan, ScanSong, and Songbase. A zero reader-conflict
  count is not sufficient: direct comparison found all 72 Medarot 4 sidecar
  titles differ from the corresponding master-queue titles. Parser support
  alone does not establish that a source set is coherent or canonical.
  Metadata uncertainty does not block UAC packaging when the GBS payloads pass
  header validation; preserve playable GBS bytes and classify unresolved
  fields in the per-set report.
  MetaMan uses M3U rows only for source track indexes, titles, queue order,
  and useful factual comments. It ignores all time, loop, fade, and repeat
  columns. Keep the embedded UAC M3U byte-exact; the manifest omits those
  timing values. Keep the exact source archive linked by `sources[]` as the
  source-state evidence.
  `::GBS` source indexes are zero-based unless that particular M3U explicitly
  says `1-indexed playlist`; then subtract one for UAC's `trackIndex` while
  preserving its authored row order and titles. Treat the note as an indexing
  directive, not a `Comment` tag, and retain its original bytes in the M3U
  attachment. Apply the directive only to the marked queue; do not shift
  sidecar indexes unless those sidecars carry their own marker. Join the
  normalized queue to per-track sidecars before title projection. The master
  title may replace repeated sidecar context only when each sidecar has the
  same normalized member/index, begins with the exact master title plus
  ` - `, and the remaining suffix is identical across the member. If the
  normalized indexes do not resolve to the declared GBS tracks, or title
  correspondence fails, leave the package in review. For a previously built
  UAC with a bad projection, correct manifest metadata only; keep all member
  and payload bytes unchanged and record the outer/manifest hash change.
  When a source master queue is used to reconstruct or replace an existing
  UAC playlist, require exactly one in-range queue row for every GBS-declared
  track. If rows are missing, keep that replacement in Review and record the
  declared count, queue coverage, and omitted source indexes. Compare the same
  exact GBS member across available source sets to determine whether the gap is
  already present in source M3Us. This distinguishes a source playlist gap from
  a UAC packaging loss but still does not identify the omitted subsong titles.
  Do not invent titles or order for omitted indexes. Ordinary first-time GBS packaging may
  still include untitled source-index entries when no complete source queue
  exists; the missing title remains unknown.

## Field Mapping

| Source Tag | UAC Tag | UAC Coded Tag | Tag Notes |
| --- | --- | --- | --- |
| GBS header Game Title | Album | `game.metadata["Album"]` | One nonempty, shared value for the physical GBS file. Do not substitute a filename or an inferred DAT title. |
| GBS header Author (MetaMan exposes `artist`) | Album Artist | `game.metadata["Album Artist"]` | Shared source value; do not duplicate it as track Artist. |
| GBS header Copyright (MetaMan exposes `comment`) | Copyright | `game.metadata["Copyright"]` | This fixed header slot is the format's copyright field; preserve its populated value as written. |
| M3U `# @TITLE value` | Album | `game.metadata["Album"]` | Use when all applicable rows agree and the value agrees with a populated header. If it conflicts, retain the header and route the case to review unless the narrow Album reconciliation rule below is satisfied by a positive title root, exact physical Catalog code, and matching M3U title. |
| M3U `# @ARTIST value` | Album Artist | `game.metadata["Album Artist"]` | Use only when the value is shared and source evidence identifies it as the musical artist/composer credit. If it conflicts with populated GBS header Author, retain the header and report the conflict. A value matching package Developer or Publisher is a company-credit claim, not automatically an alternate Album Artist; keep it in the attached M3U unless its role is independently established. |
| M3U `# @DATE value` | Date or Year | `game.metadata["Date"]` or `game.metadata["Year"]` | Preserve the source precision: a year-only value maps to Year; a partial or full calendar date maps verbatim to Date. Do not add a redundant Year when Date already contains it. |
| M3U `# @YEAR value` | Year | `game.metadata["Year"]` | Keep only when it is a distinct, compatible fact; omit it when the same year is already present in Date. |
| M3U `# @COMPOSER value` | Composer | `game.metadata["Composer"]` | Promote only a populated, unambiguous shared value. |
| M3U `# @RIPPER value` | Dumper | `game.metadata["Dumper"]` | The source uses Ripper; UAC uses the established Dumper field. |
| M3U `# @TAGGER value` | Tagger | `game.metadata["Tagger"]` | Promote only a populated, unambiguous shared value. |
| M3U `# @DEVELOPER value` | Developer | `game.metadata["Developer"]` | Promote only when present and unambiguous. |
| M3U `# @PUBLISHER value` | Publisher | `game.metadata["Publisher"]` | Promote only when present and unambiguous. |
| M3U `# @GENRE value` | Genre | `game.metadata["Genre"]` | Promote only when present and unambiguous. |
| M3U `# @COPYRIGHT value` | Copyright | `game.metadata["Copyright"]` | Compare with the GBS header comment; keep a conflicting value in the attached M3U for review. |
| M3U `::GBS,index,title,...` title | Title | `playlists[].entries[].title` | Source track title, retained as written. Do not split embedded composer, game, publisher, or copyright text out of the title. |
| M3U source index and row order | Playlist `trackIndex`, entry `title`, and entry order | `playlists[].entries[]` | Preserve the zero-based GBS source index, including hexadecimal source notation after conversion to decimal. Copy the authored track title exactly. Keep the entry array in the authored master-queue order; when no multi-row queue exists, use GBS source-index order. Do not add a duplicate Track Number tag. |
| M3U comments with useful shared facts | Canonical package tags | `game.metadata` | Use the explicit mappings above for populated, unambiguous factual comments. Preserve source values; omit blank and unknown comments. |
| M3U source path | Attachment provenance | `members[].path` and playlist `originalMemberPath` | Retain the embedded M3U byte-for-byte. Project only its source index, title, queue order, and approved factual comments into first-class manifest fields. The linked source archive remains the original source-state evidence. |
| M3U time, loop, fade, and repeat columns | Not surfaced | — | Do not project or use authored play length, loop, loop-start, fade, or repeat values as UAC metadata or duplicate-rip evidence. Preserve embedded M3U bytes unchanged for historical reference. These are arbitrary listening hints, not intrinsic GBS data. |
| GBS header version byte | Format | `playlists[].entries[].extraFields["Format"]` | Use `GBS v.<version>` on every logical track, for example `GBS v.1`. Read the byte from that physical member; never normalize versions. |
| GBS member filename stem beginning with `DMG-` or `CGB-` | Catalog | `game.metadata["Catalog"]` | Preserve the exact stem, including prefix and suffix (for example, `DMG-AIPE-USA`). Set it once at package scope when all included GBS members share one code. Do not infer it from a title, No-Intro ID, or region. A prefix or territory-looking suffix alone does not select hardware, DAT release, or `Region`; require an independent mapping for the exact full code before using it to corroborate a release. Different codes in one package require review. |

When a source UAC declares `Region` but the linked No-Intro candidate IDs omit
that regional release, an authoritative system-specific catalog may corroborate
the source region only if it maps the exact native `Catalog` code to that
region. Record the direct catalog URL, exact code, and region in the reviewed
AudioMan promotion manifest and cite the mapping in its operation report. This
preserves the source claim without fabricating a No-Intro release ID or
changing the region-neutral `Game ID`.

## Comparing GBS Source Variants

### Explicitly patched source variants

When a source package includes a patch note or marks a GBS as patched, preserve
that attachment and treat the patched package as a distinct source rendition.
The note establishes the intended change, not automatic precedence or proof
that the unpatched rendition is corrupt. Compare the complete GBS bytes,
playback data, queues, source credits, and package attachments. A reviewed
selection may promote the documented patch as the best-supported package while
keeping its unpatched peer intact in a reason-specific Review case. Never merge
the peer's tags or attachments, and do not add a generic `Patched` tag: retain
the source explanation in its bundled text file and describe the selection in
the per-case report.

Keep the complete physical GBS member and its four Stream Hashes unchanged.
AudioMan may use a report-only comparison digest built from header bytes
`0x00–0x0F` plus bytes `0x70` onward, excluding only the header's title, author,
and copyright string area (`0x10–0x6F`). These offsets follow the
[GBS header definition](https://github.com/mmitch/gbsplay/blob/master/gbsformat.txt).
Matching comparison digests show identical playback-defining header fields and
code/data bytes; they do not make the complete GBS files byte-identical or
establish common source provenance. Never surface this diagnostic digest as a
UAC tag or substitute it for the full member hash. Before preferring or
retiring a same-root package, compare all physical GBS members, M3U queues and
titles, useful source tags, and retained attachments. Preserve conflicting
source claims until their accuracy has been resolved. If a complete UAC is
selected for a master set, keep that source package and its metadata intact;
leave non-identical peers in their reason-specific review case. Do not copy a
peer's tags or attachments into the selected UAC without a separate, reviewed,
source-scoped metadata decision.

For Master selection, first require a positive No-Intro title root and a
release/Region supported by the package's source Catalog or other reviewed
release evidence. When same-root packages share playback-defining bytes but
have different full GBS hashes, compare source provenance, populated factual
metadata, named playlist entries, and attachments. A package with stronger
source-backed coverage may be selected whole; record unresolved disagreements
such as different Year/Date claims in the case report and keep the other UAC
as a header variant. This is a source-package selection rule, not a claim that
every selected source field is independently correct.

## Source-Filename Metadata

The exact original archive name is retained in the package's source record.
When that filename follows the source's documented Game Boy naming pattern,
its release-date and company fields are useful package metadata:

- A parenthesized `YYYY` maps to package `Year`. Parenthesized `YYYY-MM` and
  `YYYY-MM-DD` map verbatim to package `Date`, retaining the source precision.
  Do not complete a partial date or add a redundant `Year` beside a `Date`
  whose value already contains the year. Fuzzy values such as `19xx` remain
  source evidence and are not projected as a date.
- After the date, the first company group is a `Developer` candidate; a second
  group is a `Publisher` candidate. When a source writes two roles
  comma-separated in one group, split exactly two names into those candidates.
  If the source explicitly writes `(-)` followed by one company group, use
  that company for both roles. A single company group without a role
  separator supplies only a `Developer` candidate. These filename positions
  are conventions, not proof of a company's role for that particular release:
  check release-specific credits when another source conflicts, and correct a
  role only with cited evidence. More than two company names or groups, a
  dash combined with multiple company names or groups, or a filename that
  does not follow this structure goes to a filename-metadata review case; do
  not discard or guess at the additional names. A positive title-root or
  territory match does not clear this hold: keep the complete package in
  Review until its Developer/Publisher mapping is resolved from release-specific
  evidence. Preserve the exact filename and source archive; do not promote a
  metadata-incomplete candidate merely because its playback bytes are shared
  with a better-documented package.
- These are package-level source credits. Keep GBS header `Author` as
  `Album Artist`; do not replace it with the filename's Developer or Publisher.
- Use the source archive's exact recorded `sourceName`, not a later canonical
  output filename. If a populated UAC value conflicts with the filename value,
  retain both original evidence forms and leave the tag unchanged until the
  conflict is reviewed. Omit absent values and placeholders.

The per-set report records filename coverage and conflicts. This input rule
does not establish a No-Intro identity or authorize canonical renaming.

## Resolving Source-Tag Conflicts

- Keep native GBS header `Author` as the primary `Album Artist` claim. An M3U
  `@ARTIST` value that repeats package `Developer` or `Publisher` is not a
  second composer claim by itself. Preserve the attached M3U and do not
  promote the company value over the header without role-specific evidence.
- Correct an apparent `Album` typo only when the positive canonical game
  identity and independent source evidence converge. The specific exception to
  the mapping table above is a populated GBS header title that conflicts with
  an M3U title but has a physical `Catalog` code that maps to the M3U title's
  No-Intro root. Check the exact code against release/catalog evidence, not a
  filename guess. Record the old and new UAC `Album` values and citations in
  the package transformation history and set report; preserve the conflicting
  native GBS header byte-for-byte and do not change bundled GBS or M3U bytes.
- Treat case, punctuation, diacritics, conjunctions, and article-order
  differences as normalization evidence, not automatic authority to rewrite a
  source title. Hold expanded/shortened titles or titles that still conflict
  with the positive game identity for per-case review.
- Company names harvested from filenames can have release-dependent roles.
  When external credits show that a filename-position assignment is wrong,
  correct only the affected role, preserve the exact source archive name, and
  cite the release-specific evidence. Do not infer additional roles from an
  ambiguous list.

## Application Behavior

- **MetaMan** reads the fixed GBS header and matching NEZplug extended-M3U
  rows for track indexes, authored titles, and useful comments. It does not
  interpret GBS M3U timing columns. One-row M3Us annotate a track; a multi-row
  master queue sets playlist order. If no master queue exists, source GBS index
  sets order. Shared comments resolve by track index, so absent sidecar
  comments do not create false conflicts. Conflicting titles or populated
  factual comments remain diagnosed and unpromoted.
- **UACMan writer** places shared header identity in package `game.metadata`
  and source `Title`, `Format`, `trackIndex`, and playlist order on each
  logical playlist entry. It omits M3U timing and nested `M3U` tags. A
  one-track GBS still gets an explicit subsong entry. The
  Tag Analyzer reads and edits first-class playlist titles and entry
  `extraFields` in their original playlist-entry scope.
- **MetaMan UAC reader and ScanSong** expand each mapped subsong to one logical
  track row. They expose source `Title`, `Format`, source track index, and
  queue order. GBS entries never produce playback timing or loop values.
- **AudioMan Songbase** retains the ordered source playlist JSON in
  `uac_package_manifests.playlists_json` and indexes first-class title,
  source track index, and per-entry metadata under `archive_metadata_fields` as
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
- **Header count validation** — The version, declared song count, and first-song
  fields are separate bytes at offsets `0x03`, `0x04`, and `0x05`. Read the song
  count from byte `0x04`; do not combine adjacent bytes into one integer. The
  header's first-song value is one-based, while UAC playlist `trackIndex` values
  are zero-based. Compare the declared count with the playlist entry count and
  report differences; do not alter the GBS member.
- **Identity and platform** — A GBS signature identifies the container, not
  whether the music belongs to Game Boy or Game Boy Color. Use source
  platform evidence and the format-agnostic No-Intro identity workflow; hold
  titles that resolve differently across the GB and GBC DATs for review. When
  the game root is positive, put the canonical DAT title root string in
  package **Game ID** exactly, without a region or revision suffix; store a
  supported territory separately in **Region**. When the positive title root
  is established but reviewed release evidence still spans multiple regions,
  set package `Region` to `--`; keep the filename region-neutral and do not
  choose one DAT release. Leave Region absent until that review is complete.
  A populated `Game ID` such
  as `Title EU` with no separate `Region` is a metadata conflict to review
  before Master promotion, not a canonical title root. A year-only or partial
  date does not establish territory. An exact full source `Date` may corroborate
  `Region` only under AudioMan's shared canonical-game-metadata rule: trace the
  date to the original filename or embedded source field, and require two
  independent cited release catalogs to map that exact day to one territory
  among the linked DAT candidates, with different dates for competing
  territories. Preserve the source Date and document its source path, candidate
  DAT IDs, and catalogs; this does not choose a DAT release ID. Never use a
  generated filename, unattributed date, or Catalog prefix for this inference.
  A date cannot override conflicting source Catalog or Region claims; preserve
  and report conflicts without silently changing them. This identity rule
  does not select a ROM revision. Keep numeric DAT IDs in AudioMan only.
- **Named non-DAT demos and homebrew** — An independent, title-specific
  catalog can establish a demo's or homebrew production's platform even when
  No-Intro has no title root for it. In that case, set structural
  `game.console` from the cited catalog and route it to that console's Review
  tree under `Non-DAT Homebrew`. Do not create a No-Intro link or package
  `Game ID`; leave that field absent, preserve the source `Album`, title,
  developer, and set provenance, and record the external identity evidence in
  the per-set report and the UAC transformation details. Preserve harvested
  source `Year`/`Date` fields when an external catalog has a different date;
  report both claims without changing the source tag. A GBS signature,
  source-set folder, or title snap alone cannot establish the platform. If
  catalogs disagree or identify only a broad franchise, keep the package in
  its current Review bucket.
- **Non-DAT unlicensed releases** — A title-specific catalog may establish an
  unlicensed Game Boy release as a real non-DAT title. Route it to
  `Game Boy (Review)/Non-DAT Unlicensed/`, leave No-Intro `Game ID` and
  `Region` absent, and record the exact catalog listing and source-title
  evidence in the per-set report. A weak token collision with a retail DAT
  title does not turn the unlicensed package into that retail game. Catalog
  presence alone does not select a territory, ROM revision, or preferred rip.
- **Cross-platform productions** — When a title-specific catalog lists a demo
  or music pack for both GB and GBC, preserve that multi-platform claim in the
  per-set report. Do not duplicate one GBS package into both console trees or
  force a single-console correction without member-specific evidence.
- **Explicit NSF conversions** — If the source catalog labels a GBS item `NSF Conversion`, treat that as evidence of converted NES/Famicom music, not as a
  Game Boy retail-game identity. Keep it in `Platform-Conflict` while the
  profile's source-game versus playback-platform mapping is unresolved. Do not
  assign a No-Intro `Game ID`, move it to an NES Master, or mark it corrupt from
  the GBS signature or title alone. Record the exact source catalog and the
  originating game's platform evidence in a per-case report.
- **Cross-DAT routing** — A source-set folder label and a shared GB/GB-C
  container format do not settle the platform. Correct `game.console` only
  after a positive identity link is supported by release-specific title,
  catalog, or source metadata. Once the platform is established, route
  unresolved same-title rip variants to that console's Review tree; a matching
  GBS body after the 112-byte header is diagnostic and never authorizes
  replacement or deletion. Keep the source `Set Name`, `Set URL`, and member
  bytes intact.
- **Title Snap** — When one title-screen PNG can be matched to the positive
  Game ID root and the correct GB/GBC family, embed it as a package-level
  `Title Snap` attachment. Prefer an exact normalized title match; a unique
  whole-word match is acceptable only when the report shows one root and the
  artwork itself supports it. Do not use artwork to infer a region, revision,
  or positive game identity. If the image set has region/revision alternatives,
  multiple distinct PNGs, or no unique candidate, leave the tag absent and
  record the case in the set report. Keep the PNG bytes in the UAC and record
  its source pack/member and BLAKE3 in the transformation evidence. The
  Dashboard `TS` mark reports attachment resolution only. If no verified image
  exists in the available source packs, leave `Title Snap` absent, report the
  TS gap, and keep it as an open artwork task; do not guess an image or block
  positive title identity on the missing art alone.
- **UAC packaging with unresolved metadata** — A package whose GBS members
  pass signature, header-length, nonzero-version, and nonzero-track-count
  checks can be wrapped even when source metadata needs later review. Bucket
  the uncertainty in the AudioMan set report; packaging does not resolve the
  case. Preserve every playable GBS member and applicable M3U attachment
  byte-for-byte; keep timing columns only inside the attached M3U file and out
  of the surfaced manifest. Preserve other
  unexplained companions byte-for-byte. Project only populated, unambiguous
  source-backed fields. Omit conflicting playlist/header fields and non-ASCII
  fixed-header strings until resolved; the exact source GBS remains bundled,
  and the source archive remains linked for the original M3U bytes. Add one
  logical playlist entry per declared track with
  `Format` on every entry and retain the four playable-payload hashes for
  every physical GBS. If no unambiguous M3U supplies a track title, leave it
  absent. Do not add a `Game ID` until the canonical title
  root has positive No-Intro evidence. Keep each unresolved package in its
  uncertainty bucket and case report. Metadata uncertainty alone does not
  create a `Status` tag; use a non-empty `Status` only for the established
  Mixed Versions, Incomplete, or Corrupt conditions.
- **Multiple GBS members** — Project the native `game`, `artist`, and
  `comment` values (Game Title, Author, and Copyright) to package scope only
  when the included physical GBS members agree. The current MetaMan/UAC
  metadata harvester keeps only shared header
  values at package scope and does not preserve varying header values on each
  physical member. Omit header fields that disagree across members and route
  the package to the varying-header bucket; raw member bytes remain bundled.
  Do not assume a varying header
  `artist` (the source Author field) is a track `Title`, or replace a
  conflicting header with the outer archive filename. Record each package as
  its own review case.
- **Header text encoding** — The [GBS format reference](https://github.com/mmitch/gbsplay/blob/master/gbsformat.txt)
  defines fixed-width Game Title, Author, and Copyright strings but does not
  identify a character encoding. ASCII values can be projected normally. For
  non-ASCII bytes, MetaMan omits that individual decoded field; do not assume
  UTF-8 or Windows-1252 and do not surface mojibake. Preserve the source GBS
  unchanged, include exact GBS bytes in the header-encoding bucket, and hold
  decoded values until the encoding is verified for that source. A CP932 rendering may be
  shown as a review aid, but it is not approved metadata until confirmed.
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
- **Set identity** — Follow the base profile and identify the package's
  immediate source distribution, not the later JohnS conglomerate. For the
  current JoshW source use `Set Name: JoshW` and
  `Set URL: https://gbs.joshw.info/`. For GBS Penultimate use its recorded
  source identity (`Set Name: Game Boy`,
  `Set URL: https://snesmusic.org/hoot/gbs/`). Do not copy either source's
  tags onto the other source's packages. If a source's set name or URL is not
  established, omit that field rather than inventing one.
- **GBS header fields** — Validate the 112-byte fixed header, `GBS` signature,
  nonzero version and track count, and the declared first-track index. Keep
  load/init/play addresses and timer bytes as validation evidence only; do
  not promote them to user-facing tags. Treat `?`, `<?>`, and `< ? >` header
  placeholders as absent so they do not block a populated M3U value.
- **M3U files** — Retain applicable M3Us as package attachments, including
  multiple M3Us that refer to the same GBS. Preserve each attached M3U
  byte-for-byte. Project file references, source indexes, titles, authored
  order, and approved factual comments into the manifest; do not surface timing,
  loop, fade, or repeat values there. The linked source archive remains the
  exact source-state copy.
  A row reference may omit the final `.gbs` suffix; resolve it to an exact,
  case-insensitive member stem only when that identifies one physical GBS.
  Hold a source package with colliding member stems for review.
  `::KSS` and `::GBS` are distinct NEZplug type markers, not synonyms. If a
  `::KSS` row names a `.gbs` file, resolve the exact path and validate the
  target's GBS signature, record a source marker mismatch, and hold the package.
  Do not silently coerce the marker or project that row as GBS until an
  explicit recovery rule exists; retain factual row data and report the marker
  mismatch. Timing columns in the retained attachment are not projected to
  manifest fields.
  Copy each resolved track title to the first-class playlist entry `title`;
  retain its zero-based source index in `trackIndex` and preserve the authored
  queue in entry-array order. Do not create a nested `M3U` tag, duplicate
  Track Number tag, raw row, or timing projection. Shared factual comments use
  the explicit package mappings above. `originalMemberPath` and the bundled
  M3U member preserve source-path provenance.
- **M3U row conflicts** — Compare all rows for the same GBS member and
  zero-based index. If titles or factual comments disagree, retain the
  competing source rows and route the track/package to its own case review.
  Differences in time, loop, fade, or repeat columns are discarded and do not
  create a conflict or distinguish same-stream rips. Do not silently select the richest row, merge rows, or
  treat a second title as a duplicate without evidence. A one-row sidecar annotates its referenced
  track and does not assert queue order. Preserve the order from the authored
  multi-row queue; hold repeated indexes or genuinely different multi-row
  queue orders for review.
  Also compare every multi-row master M3U directly with matching one-row
  sidecars. Reader diagnostics alone are not a sufficient conflict check:
  Medarot 4's 72 master titles and 72 sidecar titles differ even though the
  preflight reported zero reader conflicts. Retain both factual forms in review
  evidence and hold the package until the title role is resolved, unless the
  narrow repeated master-title prefix rule below succeeds.
  Apply this check by member and zero-based source index: a differing master
  queue title and one-row sidecar title are two source claims, not an automatic
  replacement or proof of a different rip, except under the exact repeated
  prefix condition below. Keep both byte-exact M3Us attached
  when rebuilding from that source, preserve the master queue order, and leave
  the disputed per-track `Title` out of the UAC surface until its display role
  is resolved. Record title agreement between separate source sets as evidence,
  but do not let agreement erase the master-versus-sidecar role distinction.
- **Repeated master-title prefix** — A narrow exception applies only when every
  one-row sidecar resolves to exactly one member and source index in the
  multi-row master queue, every sidecar title begins with that exact queue title
  followed by ` - `, and the remaining suffix is the same for every sidecar
  title for that GBS member. Treat that invariant suffix as repeated package
  context, not as part of each track title. Surface the master-queue title,
  retain the queue's authored order, and keep both M3U layers byte-exact; do not
  parse the suffix into tags. Any missing index, nonmatching prefix, or
  noninvariant suffix falls back to the per-index conflict rule above. This
  exception resolves title role only; comments and other factual fields still
  require their explicit field mapping and conflict checks.
- **GBS duplicates** — Compare physical GBS member identity and multiplicity.
  The full physical-member BLAKE3 is the exact byte-identity test. A comparison
  of bytes after the 112-byte fixed header is diagnostic only: matching program
  bodies with different headers are not byte-identical GBS files and do not
  authorize deletion or automatic replacement. Compare declared track count,
  first track, playback addresses/timer fields, native title/author/copyright,
  Catalog code, and M3U title/order data. Keep different header variants
  available until those differences are reconciled. M3U timing values never
  distinguish rips. Track names, source indexes, and queue order remain
  separate curation facts and must be checked before selecting a
  title/order projection when sources disagree.
- **Composite titles and comments** — Keep a composite M3U title as one Title
  value. Promote a recognized, populated `# @KEY` value only through an
  explicit useful-field mapping with canonical Title Case tag names. Current
  shared mappings are Title, Artist, Date, Year, Composer, Ripper, Tagger,
  Developer, Publisher, Genre, and Copyright. Do not surface raw lower-case
  source keys, empty values, placeholders, freeform comments, unknown keys, or
  parser diagnostics as UAC tags; retain the byte-exact M3U attachment and
  exact source-archive link.
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
  zero-based track index. Preserve title, source index, and authored queue
  order. Treat one-row files as track annotations. Hold repeated indexes,
  out-of-range references, conflicting titles, or competing queue orders for
  review; retain byte-exact M3U attachments and report missing, duplicate, or
  conflicting references.
  Verify the track-index/title/order sequence before treating same-stream
  representations as metadata-equivalent.
- **M3U reader coverage** — Confirm every authored row was actually projected
  into the UAC playlist. Compare source row totals, indexes, titles, and queue
  order across master M3Us and one-row sidecars, even if the reader emits no
  diagnostic. Ignore timing-column differences. Hold `::KSS` rows that
  reference validated `.gbs` members as marker mismatches; retain their
  byte-exact M3U attachment without interpreting its timing columns.
- **Timing omission** — Confirm no GBS playlist entry, nested tag, member tag,
  or playback projection contains play length, loop, loop start, fade, repeat,
  or other authored timing values. Embedded M3U files may retain their original
  timing text byte-for-byte; never surface or use it. The source archive linked
  through `sources[]` is the source-state evidence. Timing differences never
  distinguish same-stream rips.
- **Tag scope** — Confirm Album and Album Artist are shared only when their
  source values agree, track titles remain attached to the correct index, and
  no empty, inferred, or diagnostic tags were added.
- **Catalog** — When all playable GBS members in a package share one
  `DMG-`/`CGB-` filename stem, confirm that exact stem is present once as
  package `Catalog`; hold differing member codes and do not infer the value.
- **UAC review** — Verify Title and Format are visible on each logical track,
  package metadata stays at package scope, hashes are visible
  in Stream Hashes, and byte-exact M3Us remain available as package attachments.
  The Tag Analyzer's playable-track count and playlist-entry rows expose
  subsong metadata; the physical-member Tracks grid can show one GBS file for
  many logical subsongs. Keep affected conversions held until competing M3U
  rows are reviewed.
