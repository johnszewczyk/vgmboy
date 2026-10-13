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
- **M3U and attachments** — Retain each applicable M3U in the UAC with its
  file references, source indexes, titles, queue order, and factual comments.
  Strip play length, loop, fade, and repeat columns from the bundled copy.
  The exact source archive linked through `sources[]` retains the original M3U
  bytes. Keep other package attachments byte-exact and classify them before
  packaging.

## Identity and Naming

- **Source title** — Preserve the GBS header game name as Album. Do not infer
  Game ID, region, developer, publisher, or canonical filename from a source
  filename alone.
- **Game ID** — Add the No-Intro canonical game-root title only after a
  positive AudioMan match. Leave it absent while identity is unresolved.
- **Filename** — Keep the source package name until identity review establishes
  a canonical title and any needed collision detail.

## Set Procedures

- **Native fields** — Apply the GBS profile's shared and track mappings.
  Populated M3U `@RIPPER` and `@TAGGER` map to Dumper and Tagger. Omit blank
  fields and placeholders. Keep unknown comments in the attached M3U without
  inventing UAC tags.
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
- Confirm every M3U row resolves to a declared zero-based GBS track, playlist
  titles and order are preserved, and factual comments agree across
  applicable M3Us. Ignore timing-column differences.
- Confirm Album, Album Artist, Date/Year, Composer, Dumper, Tagger, Developer,
  Publisher, Genre, and Copyright are populated only from their mapped GBS,
  M3U, or source-filename fields; omit placeholders and empty values. Report
  filename conflicts without overwriting the conflicting UAC value.
- Confirm all applicable M3U facts are retained, their bundled timing columns
  are removed, other retained attachments are byte-exact, and the logical
  track entries retain Title, Format, source index, and queue order without
  nested M3U timing values. The physical GBS appears once with its four
  Stream Hashes.
- Review the package in UACMan Tag Analyzer and confirm no unapproved tags or
  authored playback timings were added.
