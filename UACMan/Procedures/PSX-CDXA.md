# PlayStation CD-XA and Red Book to UAC

This profile covers Redump PlayStation discs whose music is stored as native
CD-XA sectors, Red Book CD-DA tracks, or both. MetaManCore reads XA headers and
APE metadata. The UAC keeps original XA sector members byte-for-byte and
represents verified Red Book audio as APE; it does not replace the Redump
source archive.

## MetaManCore XA fields

The `xa` reader reports these `nativeMetadata.technicalFacts` when the XA
header exposes them:

| Field | Meaning |
| --- | --- |
| `container` | Member representation, such as `raw-sector`. |
| `form`, `codingInfo`, `submode`, `xaConfiguration` | XA sector coding/header facts. |
| `bitsPerSample`, `channels`, `sampleRateHz` | Values decoded from the XA coding byte. |
| `sampleCountPerSector`, `audioSectorCount` | Measured audio frame and sector counts. |
| `sectorHeaderBytes`, `sectorPayloadBytes`, `sectorSizeBytes` | XA sector layout. |
| `xaFileNumber`, `xaChannelNumber`, `visibleTrackIndex` | Stream identity in the source disc. |

Keep those facts in the MetaMan technical object. Do not flatten them into
duplicate `XA_*` track tags. A raw XA sector stream has no generic-purpose tag
block and this profile does not define a CD-XA **Sub-Container Version** tag.
Do not expose the reader's descriptive `comment: Sony XA header` as a source
comment. It is a reader placeholder, not native tag data.

## UAC member fields

| Evidence | UAC location | Rule |
| --- | --- | --- |
| Populated music metadata | `member.metadata` | Retain only meaningful Album, Title, Artist, Composer, Date, Year, Publisher, Developer, Disc Number, Track Number, and source OST fields when present. Preserve original populated values. |
| XA technical facts | `member.metadata.nativeMetadata.technicalFacts` | Keep MetaManCore values, including valid format-specific variation. Do not add duplicate user tags. |
| XA-to-disc mapping | `member.metadata.sourceXA` | Keep the source BIN sector range and XA file/channel identity when known. Keep one structured representation. |
| Validated native loop | `member.metadata.loop` | Include only a positive, source-backed loop mapping. The playlist may repeat that positive object for playback. |
| No loop | no field | Omit `loop`, `loopStatus`, `LOOP_TYPE=none`, and all equivalent negative tags. Absence means no loop was identified. |
| Stream hashes | `member.hashes[]` | Keep the four playable-payload hashes (BLAKE3-256, CRC32/ISO-HDLC, SHA-1, MD5) for the exact stored stream bytes. Do not duplicate them as `SOURCE_XA_*` tags. |
| Disc/source hashes and URL | `sources[]` | Keep the source archive, BIN, CUE, and source-set identifiers at package/source scope, not repeated on every track. |
| APE-native tags | `member.metadata.nativeMetadata.tags` | Read through MetaManCore. Retain populated music tags; omit synthetic loop sentinels and repeated system, region, and CUE facts already represented structurally. |

Keep measured `playLengthMs`. Keep the CUE as a byte-exact UAC member and use
its structured reference. Do not embed the full BIN or source archive unless a
package is explicitly designed to be self-contained. There is no APE
**Sub-Container Version** user tag in this profile; MetaMan's APE version fact
remains technical data.

## Procedure

1. Verify the Redump archive and its BIN/CUE identity against available source
   records. Reuse recorded hashes where the byte scope matches; do not hash a
   source again just to populate a duplicate per-track tag.
2. Extract each XA stream as its exact selected 2352-byte source sectors and
   verify member hashes against the BIN-derived selection.
3. Decode each Red Book track to PCM, encode APE, verify with Monkey's Audio,
   and compare decoded PCM against the Redump track extraction.
4. Harvest APE and XA metadata with MetaManCore. Review the fields against the
   UAC member rules above; do not promote reader placeholders or duplicate
   technical/source values.
5. Record loop evidence in the set report. Write a loop object only when the
   native source establishes one; leave all other members without a loop
   field.
6. Verify the final UAC payload, member hashes, playlists, and documentation.

The collection-specific SOTN and Darkstalkers results are recorded in
[`Reports/PSX-Redump-Metadata-Cleanup-2026-09-26.md`](Reports/PSX-Redump-Metadata-Cleanup-2026-09-26.md).
