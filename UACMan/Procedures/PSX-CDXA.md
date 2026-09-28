# PlayStation Disc Audio to UAC Profile

## Status and scope

This profile sets the PSX-specific provenance and tag-surface boundaries. The
exact track-tag vocabulary, native-tag passthrough versus UAC-manifest
synchronization, and whether a UAC package is needed for a given soundtrack
remain under discussion. Those choices must not be inferred from the SPC
profile.

The [2026-09-26 Redump cleanup report](Reports/PSX-Redump-Metadata-Cleanup-2026-09-26.md)
records packages built under the previous tag and hash rules. It remains a
historical package audit; this profile governs future PSX tag-surface decisions.

It covers Redump PlayStation disc audio represented as native XA streams,
Red Book CD-DA tracks, or both. Extraction and game-specific loop research
remain in the [PSX preservation protocol](../protocols/PSX-CDXA.protocol.md).

## Source identity and package shape

- Treat the declared Redump disc as the source identity for this PSX workflow.
  Keep its Redump release name and URL, plus the known original BIN checksums,
  once in the package source record. Reuse matching checksums already recorded
  in the database or Redump record; do not build another multi-algorithm hash
  catalog for every derived track.
- Include the original CUE byte-for-byte as an ordinary package member and
  reference it from `game.metadata.cue_sheet`. The CUE preserves the disc's
  track layout and indexes.
- Do not include the full BIN or downloaded archive by default. Keep those
  source files in their source-study location and link them by the package-level
  source record. A self-contained disc-image package would be a separate,
  explicit packaging choice.
- A UAC is an optional convenience bundle for lossless audio members and the
  CUE. A tagged APE/FLAC collection with its CUE can remain the deliverable
  when a single UAC adds no useful handling benefit.
- The wrapper's own integrity fields remain governed by the UAC format. They
  are package integrity data, not PSX music tags. This profile adds no
  per-track four-algorithm stream-hash set, decoded-PCM hash catalog, or
  repeated source-image checksum fields.

## Track tag surface

There is no approved PSX-wide track-tag allowlist yet. Keep tag names and
values in the APE/FLAC native tag interface when present. Whether UAC should
pass those tags through or synchronize selected values into its manifest is
open; do not duplicate native values in the manifest merely to make them
visible twice.

Do not synthesize a title from a filename, a generic “Redbook Audio Track”
label, an album from a game filename, or credits from game-level information.
Do not emit blank tags. A populated CUE `TITLE` or `PERFORMER` value may be
reviewed as source metadata; its absence does not authorize a fallback value.

The following do not belong on the music-tag surface:

- Red Book/CD-DA's fixed sample format or generic format label, including
  `system: Standard audio`.
- APE encoder/version/compression details, reader diagnostics, or a nested
  technical/verification object presented as if it were one ordinary tag.
- CUE indexes, pregap values, region, and source-set facts repeated on every
  track when the attached CUE or package source record already carries them.
- Negative loop markers. Store a loop only when the PSX source research
  establishes a positive loop; otherwise omit loop fields.

Measured playback duration may be retained as operational timing data where a
UAC consumer needs it. It is not a music-tag decision. XA reader facts and
source-sector mappings are handled by the XA preservation protocol; do not
flatten them into invented `XA_*` tags.

The profile does not yet resolve whether the visible track fields should use
`Album`, `Game Title`, or another game/OST distinction; how physical CUE track
numbers relate to audio-only sequence numbers; how unnamed tracks should appear;
or which source can establish artist, composer, publisher, developer, year, or
official OST titles. Leave those values unchanged or absent pending review.

If a future profile decision mirrors native tags into the manifest, use the
UAC tag-map contract: a JSON object keyed by the original tag name, with arrays
for repeated values in source order. This storage shape does not decide which
tags are visible in the UACMan tag grid.

## XA interpretation

MetaManCore's XA facts describe source-sector interpretation, not conventional
music tags. Keep only the facts required by the XA reader, playback, or a
source-backed loop mapping in the appropriate structured record or research
report. Do not promote uniform technical values to visible track tags. The
game-specific XA loop and sector rules remain in the linked preservation
protocol.

## Procedure

1. Identify the declared Redump release and source BINs. Consult its published
   checksums or an exact-scope stored database record; do not rescan source
   files solely to repeat already established provenance.
2. Preserve and include the source CUE byte-for-byte when making a UAC, with a
   package-level CUE reference. Keep source BIN checksums at source scope.
3. Review actual APE/FLAC tags before deciding what to surface. Record which
   values are present in the member, which came from the CUE, and which would
   be newly authored. Do not auto-promote filenames, parser placeholders, or
   disc-format facts.
4. Decide per soundtrack whether tagged audio plus the CUE is sufficient or a
   UAC bundle is useful. If a UAC is built, use the normal wrapper integrity
   checks. The PSX profile does not require per-track PCM comparisons or a
   separate stream-hash catalog.
5. Keep verified game-native loop research for XA in the preservation report
   and encode only positive, source-backed loop data. Never emit a “no loop”
   tag or object.
6. Report unresolved title, album, numbering, or credit conflicts for review;
   do not resolve them by promoting one unverified value.
