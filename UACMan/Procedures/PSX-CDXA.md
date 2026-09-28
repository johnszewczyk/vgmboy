# PlayStation Disc Audio to UAC Profile

## Status and scope

This profile sets the PSX-specific provenance and tag-surface boundaries.
Keep the PSX surface concise and flat; do not inherit SPC-specific hashes or
metadata policy. Selected ordinary tags belong directly in UAC package/member
metadata so UACMan can read them without opening the audio payload. The source
audio bytes remain unchanged.

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

Use proper Title Case for visible tag names and store each selected value as an
ordinary, direct UAC metadata field. Do not create a `NativeMetadata` object or
copy the full reader output into a hidden/nested map. The unchanged APE/FLAC
member remains the byte-exact preservation copy of its native tags. Project
only useful, populated, source-backed values to UAC metadata; do not duplicate
one fact under aliases.

Current PSX projection direction:

| Field | UAC location and rule |
| --- | --- |
| Platform | Use the shared `game.console` field with value `PSX`. Present it to users as **Platform**; do not add duplicate `system` or `platform` metadata keys. |
| Album | Use the standard **Album** member tag for the established game/soundtrack title (for example, `Darkstalkers - The Night Warriors`). Do not add a parallel `Game` tag or append the region to Album. |
| Region | Keep the release region once at package scope as `game.metadata["Region"]`, using the two-letter code (for example, `US`). Use the same code in the package filename, such as `(US)`, not `(USA)`. |
| Title and credits | Preserve populated, useful, source-backed tags such as **Title**, **Artist**, **Composer**, **Publisher**, and **Developer** under those names. Do not infer credits from a game's company identity or synthesize a title from a filename. |
| Year and Date | Keep populated, source-backed values under **Year** and **Date**. Do not invent values or add blank tags. |
| Contained / Subcontainer | Prefer the concise label **Contained** for the proposed common field. Its value vocabulary and whether it describes each member or the package still need a shared UAC contract decision; until then, do not emit competing `format`, `Contained`, and `Subcontainer` aliases. |

Do not create a visible `Disc Track Number` or `discTrackNumber` tag. The
byte-exact attached CUE carries physical disc track numbers and indexes; the
ordered UAC playlist carries playback order. Do not conflate those two number
spaces. A conventional audio track number may be added only if a consumer
requires it and its sequence is explicitly defined.

Do not synthesize a title from a filename, a generic “Redbook Audio Track”
label, an album from a game filename, or credits from game-level information.
Do not emit blank tags. A populated CUE `TITLE` or `PERFORMER` value may be
reviewed as source metadata; its absence does not authorize a fallback value.

The following do not belong on the music-tag surface:

- Red Book/CD-DA's fixed sample format or generic format label, including
  `format` or `system: Standard audio` tags.
- APE encoder/version/compression details, reader diagnostics, or a nested
  `NativeMetadata`, technical, or verification object on the PSX music-tag
  surface.
- CUE indexes, pregap values, region, and source-set facts repeated on every
  track when the attached CUE or package metadata already carries them.
- Negative loop markers. Store a loop only when the PSX source research
  establishes a positive loop; otherwise omit loop fields.

`playLengthMs` is optional operational timing, not a music tag and not a
decode-required field. UACMan uses it for duration display and sorting;
catalog/player presentation uses it for track length and playlist-total
readouts. Keep a positive, source-backed value when those readouts benefit, but
do not invent a fallback or mistake it for a decoder instruction.

`pregapFrames` has no production consumer in the inspected UACMan, ScanSong, or
CocoaSpice source. The attached CUE already records physical indexes/pregaps,
and the current extraction keeps the audio samples in the member. Do not copy
`pregapFrames` into track metadata or playlist extras; retain the CUE unchanged.

XA reader facts and source-sector mappings belong only in the preservation
record where a decoder or verified loop mapping needs them. Do not serialize a
broad `NativeMetadata` object or flatten reader facts into invented `XA_*`
tags. Keep any required positive loop mapping in its playback structure and
source-sector evidence in the report.

For this PSX profile, selected source tags are projected as direct member
metadata fields; unselected native tags remain only in the byte-identical audio
member. Do not create a native-tag map or an alternate `{name, value}` list.

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
3. Review actual APE/FLAC tags before deciding what to surface. Project only
   populated, useful, source-backed fields from the profile above. Record which
   values came from the member, which came from the CUE, and which would be
   newly authored. Do not auto-promote filenames, parser placeholders, or
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
