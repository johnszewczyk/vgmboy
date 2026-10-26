# JoshW GBS Set Profile

Apply the [Base Set Profile](BASE-SET-PROFILE.md) and the
[GBS Profile](../GBS.md). This is an input rule for GBS source packages from
the JoshW Game Boy catalog; actual coverage and exceptions belong in
AudioMan's per-set reports.

## Scope

- **Collection** — The Game Boy Sound System catalog at
  `https://gbs.joshw.info/`.
- **Format** — This profile covers `.gbs` packages in the Nintendo Game Boy
  and Nintendo Game Boy Color source folders. Super Game Boy packages remain
  held until their platform identity is reviewed.
- **Package selection** — Keep one source archive as the provenance unit.
  Do not combine separate archives or variants just because their game names
  match. Hold multi-GBS packages, unresolved or conflicting M3U rows, invalid
  headers, mixed versions within one package, and unclassified extra members.

## Source Authority

- **Package fields** — Set Name is `JoshW`; Set URL is
  `https://gbs.joshw.info/`. Keep both at package scope.
- **Source archive** — Preserve the original source-state archive outside UAC.
  Link each UAC to that exact archive through `sources[]`; do not bundle the
  outer archive or surface its hashes as GBS stream hashes.
- **M3U and attachments** — Retain each applicable M3U in the UAC byte-for-byte,
  including file references, source indexes, titles, queue order, factual
  comments, and authored play length, loop, fade, and repeat columns. Project
  only the approved playlist facts into the manifest; do not surface timing
  hints or use them to distinguish rips. The exact source archive linked
  through `sources[]` also remains the source-state evidence. Keep other
  package attachments byte-exact and classify them before packaging.

## Identity and Naming

- **Source title** — Preserve the GBS header game name as Album. Do not infer
  Game ID, region, or canonical filename from a source filename alone.
- **Game ID** — Add the No-Intro canonical game-root title only after a
  positive AudioMan match. Leave it absent while identity is unresolved.
- **Filename** — Keep the source package name until identity review establishes
  a canonical title and any needed collision detail.
- **Filename credits and dates** — Parse the exact recorded source archive
  filename using the [GBS source-filename rules](../GBS.md#source-filename-metadata).
  A single company group after the date supplies Developer; two groups supply
  Developer then Publisher; `(-)(Company)` supplies that Company as both.
  A year-only date supplies Year; a partial or full date supplies Date at its
  recorded precision. Do not infer Game ID or region from those fields.
  Preserve any populated M3U/header metadata that conflicts and route the
  package to a filename-metadata review case.

## Set Procedures

- **Native fields** — Apply the GBS profile's shared and track mappings.
  Populated M3U `@RIPPER` and `@TAGGER` map to Dumper and Tagger. Omit blank
  fields and placeholders. Package-level Developer, Publisher, Date, and Year
  may also come from the exact source archive filename under the GBS profile's
  filename rules. Keep unknown comments in the attached M3U without inventing
  UAC tags.
- **Master queue and sidecars** — Compare every sidecar to the multi-row
  master queue by physical member and normalized zero-based source index. If
  the master explicitly says `1-indexed playlist`, subtract one from its row
  indexes before joining; leave sidecars at their declared base unless they
  carry their own marker. Use the narrow repeated-title-prefix exception in
  the GBS profile only when every sidecar starts with its exact master title
  plus ` - ` at the same normalized member/index and its remaining suffix is
  invariant for that member. Otherwise retain the title claims for review.
  This resolves the repeated package-context suffix only; keep the original
  M3U bytes and authored master queue order, and do not surface the suffix as
  track metadata. For an already built UAC with an index-base projection error,
  make a manifest-only correction, re-index the exact scope in Songbase, and
  record the old/new outer and manifest hashes; do not rewrite the source
  attachments or Distribution Museum records.
- **Exact-clone replacement coverage** — When using a JoshW master M3U to
  rebuild a UAC whose GBS member is an exact byte clone from another set,
  require one unique in-range master-queue row for every GBS-declared track.
  Keep the replacement in Review when the queue is partial; record its row
  count and omitted source indexes. Do not fill gaps from a different set's
  titles or synthesize titles for missing rows. Ordinary first-time GBS
  packaging may still include untitled source-index entries under the base GBS
  profile when no complete queue is available.
- **Hashes** — Store the four standard compact hashes for each physical GBS
  member under UAC Stream Hashes. Hash each GBS once, regardless of its
  playlist track count. Do not put outer archive hashes in Stream Hashes.
- **Identity enrichment** — Apply No-Intro and prior positive stream identity
  records after the source metadata pass. Do not treat byte identity as proof
  of title, region, or source provenance.
- **Status** — Add `Status: Mixed Versions`, `Status: Incomplete`, or
  `Status: Corrupt` only when supported by the set review. Omit Status when
  no known issue applies; never add `Good`.

## Required Checks

- Confirm the selected GBS bytes and each original archive's source link match
  Songbase/source inventory evidence.
- Confirm every M3U row resolves to a declared zero-based GBS track after any
  explicit index-base marker is applied, playlist titles and order are
  preserved, and factual comments agree across applicable M3Us. Confirm
  sidecars join by normalized physical member/index. Ignore timing-column
  differences.
- For an exact-clone replacement, confirm master-queue coverage equals the
  GBS header's declared track count and indexes cover every source track
  exactly once; otherwise keep the package in Review with omitted indexes
  recorded.
- Confirm Album, Album Artist, Date/Year, Composer, Dumper, Tagger, Developer,
  Publisher, Genre, and Copyright are populated only from their mapped GBS,
  M3U, or source-filename fields; omit placeholders and empty values. Report
  filename conflicts without overwriting the conflicting UAC value.
- Confirm attached M3U bytes remain byte-exact, including timing columns;
  surface only approved M3U facts. Other retained attachments must also remain
  byte-exact. Logical track entries retain Title, Format, source index, and
  queue order without nested M3U timing values. The physical GBS appears once
  with its four Stream Hashes.
- Review the package in UACMan Tag Analyzer and confirm no unapproved tags or
  authored playback timings were added.
