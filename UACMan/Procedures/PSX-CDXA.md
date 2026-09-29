# Sony PlayStation Disc Audio to UAC Profile

## Status and scope

This profile sets the PSX-specific provenance and tag-surface boundaries.
Keep the PSX surface concise and flat; do not inherit SPC-specific hashes or
metadata policy. Selected ordinary tags belong directly in UAC package/member
metadata so UACMan can read them without opening the audio payload. The source
audio bytes remain unchanged.

The [2026-09-26 Redump cleanup report](Reports/PSX-Redump-Metadata-Cleanup-2026-09-26.md)
records packages built under the previous tag and hash rules. It remains a
historical package audit; this profile governs future PSX tag-surface decisions.
The [Darkstalkers track-number repair](Reports/PSX-Darkstalkers-Track-Number-Repair-2026-09-29.md)
and [SOTN metadata cleanup](Reports/PSX-SOTN-Metadata-Cleanup-2026-09-29.md)
record current examples of the physical CD-DA and logical XA numbering rules.

It covers Redump PlayStation disc audio represented as native XA streams,
Red Book CD-DA tracks, or both. Extraction and game-specific loop research
remain in the [PSX preservation protocol](../protocols/PSX-CDXA.protocol.md).
System identity follows the [shared system-name registry](CANONICAL-SYSTEM-NAMES.md).

## Source identity and package shape

- Treat the declared Redump disc as the source identity for this PSX workflow.
  Keep its Redump release name and URL in the package source record. Put known
  original BIN/CUE checksums in the included verification attachment, reusing
  matching database or Redump records rather than rehashing large images.
  Preserve the source archive hashes only when already established.
- Project verified package identity as direct Title Case tags **Game ID**,
  **Region**, **Set Name**, and **Set URL**. Do not add **Set Collection**;
  broader collection context belongs in the source record. Omit **Year** and
  **Date** when the source does not provide release-date evidence. A source
  `observedAt` timestamp records capture time, not a game's release date.
- Include the original CUE byte-for-byte as an ordinary package asset member.
  UACMan exposes it in the package attachment list; do not add a redundant
  lowercase `cue_sheet` tag or repeat its path on every audio member. The CUE
  preserves the disc's track layout and indexes.
- Do not include the full BIN or downloaded archive by default. Keep those
  source files in their source-study location and link them by the package-level
  source record. A self-contained disc-image package would be a separate,
  explicit packaging choice.
- A UAC is an optional convenience bundle for lossless audio members and the
  CUE. A tagged APE/FLAC collection with its CUE can remain the deliverable
  when a single UAC adds no useful handling benefit.
- Keep UAC's standard per-member integrity hashes (BLAKE3-256, CRC32/ISO-HDLC,
  SHA-1, and MD5). Do not add a duplicate `playable-payload` hash list for APE
  or FLAC tracks, a decoded-PCM hash catalog, or repeated source-image checksum
  fields. These are package integrity records, not PSX music tags. Keep known
  Redump BIN checksums with the CUE verification attachment and source
  provenance; retain source-archive hashes only when already established.

## Track tag surface

Use Title Case for stored tag names and store each selected value as an
ordinary, direct UAC metadata field. Do not create a `NativeMetadata` object or
copy the full reader output into a hidden/nested map. The unchanged APE/FLAC
member remains the byte-exact preservation copy of its native tags. Project
only useful, populated, source-backed values to UAC metadata; do not duplicate
one fact under aliases.

Current Sony PlayStation projection direction:

| Field | UAC location and rule |
| --- | --- |
| System | Set `game.console` once at package scope to `Sony PlayStation`. Do not add a duplicate member `System` or `Platform` tag. |
| Album | Use the standard **Album** member tag for the established game/soundtrack title (for example, `Darkstalkers - The Night Warriors`). Do not add a parallel `Game` tag or append the region to Album. |
| Region | Keep the release region once at package scope as `game.metadata["Region"]`, using the two-letter code (for example, `US`). Use the same code in the package filename, such as `(US)`, not `(USA)`. |
| Title and credits | Preserve populated, useful, source-backed tags such as **Title**, **Artist**, **Composer**, **Publisher**, and **Developer** under those names. Do not infer credits from a game's company identity or synthesize a title from a filename. |
| Year and Date | Keep populated, source-backed release values under **Year** and **Date**. Do not project source-capture timestamps or add blank tags. |
| Game ID | Use a package-level **Game ID** for the canonical release name including the agreed region suffix, such as `Darkstalkers - The Night Warriors (US)`. Keep **Region** separately as its two-letter code. Add a No-Intro identifier only when a verified matching record supplies it; do not substitute a guessed serial. |
| Set Name and Set URL | Store the exact source set name and URL once as direct Title Case package tags. Keep broader collection context, archive/member download identifiers, and source checksums in the source record. |
| Format | Use one direct member tag, **Format**, with the contained source format. For these Red Book tracks use `Red Book CD-DA`; CD-DA has no per-file version to append. This is distinct from structural `member.format: ape`, which identifies the stored APE encoding. |
| Track Number | Use a source-backed sequence with an explicit meaning. In a file-per-track CD-DA harvest that omits data track 01, use physical CUE track numbers for the audio members and filenames (for example, `02`–`46`). In a mixed-mode XA soundtrack, follow its logical OST sequence starting at `01`; XA streams are inside physical data track 01 and are not separate CD tracks. The attached CUE remains authoritative for physical disc numbering. |
| Disc Number | Omit a repeated `1` for a single-disc package. Keep a populated **Disc Number** when a package spans multiple source discs or the value distinguishes members. |

Do not add a second physical-track alias such as **Disc Track Number**. For a
Red Book member whose file maps one-to-one to a physical CUE audio track, use
that physical number in **Track Number**. For XA streams, keep logical OST
numbering in **Track Number** when the set follows a soundtrack sequence; the
attached CUE records that the XA data resides in physical track 01. The UAC
playlist preserves playback order. Never use one number field to silently mix
physical-disc positions and logical OST positions.

Do not synthesize a title from a filename, a generic “Redbook Audio Track”
label, an album from a game filename, or credits from game-level information.
Do not emit blank tags. A populated CUE `TITLE` or `PERFORMER` value may be
reviewed as source metadata; its absence does not authorize a fallback value.

The following do not belong on the music-tag surface:

- CD-DA sample rate, bit depth, channel count, reader/encoder facts, or a
  generic `system: Standard audio` tag. The concise source-format tag above is
  useful and is not a dump of those fixed technical facts.
- APE encoder/version/compression details, reader diagnostics, or a nested
  `NativeMetadata`, technical, or verification object on the PSX music-tag
  surface.
- CUE indexes, pregap values, region, and source-set facts repeated on every
  track when the attached CUE or package metadata already carries them.
- Negative loop markers. Store a loop only when the PSX source research
  establishes a positive loop; otherwise omit loop fields.

`Play Length (ms)` is optional operational timing, not a music tag and not a
decode-required field. UACMan uses it for duration display and sorting;
catalog/player presentation uses it for track length and playlist-total
readouts. Keep a positive, source-backed value when those readouts benefit, but
do not invent a fallback or mistake it for a decoder instruction.

`Pregap Frames` has no production consumer in the inspected UACMan, ScanSong, or
CocoaSpice source. The attached CUE already records physical indexes/pregaps,
and the current extraction keeps the audio samples in the member. Do not copy
Pregap Frames into track metadata or playlist extras; retain the CUE unchanged.

XA reader facts and source-sector mappings belong only in the preservation
record where a decoder or verified loop mapping needs them. Do not serialize a
broad `NativeMetadata` object or flatten reader facts into invented `XA_*`
tags. Keep any required positive loop mapping in its playback structure and
source-sector evidence in the report. The wrapper-defined lowercase
`metadata.loop` object is playback structure, not a free-form tag; preserve its
sample boundaries exactly.

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
2. Preserve and include the source CUE byte-for-byte as an ordinary package
   asset when making a UAC. UACMan exposes package assets in its attachment list;
   do not encode a redundant CUE pointer tag. Keep source BIN checksums in the
   CUE verification attachment and source provenance.
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
