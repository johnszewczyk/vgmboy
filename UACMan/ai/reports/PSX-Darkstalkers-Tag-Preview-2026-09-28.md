# Darkstalkers PSX UAC tag pass — 2026-09-28

> **Superseded by the final manifest and later reviews.** This preview contains
> obsolete one-based Track Number, Disc Number, Set Collection, and hash-list
> claims. For the current package state, see the [2026-09-29 track-number
> repair report](PSX-Darkstalkers-Track-Number-Repair-2026-09-29.md) and the
> [PSX beta review, pass 1](PSX-Beta-UAC-Review-2026-09-29.md).

## Candidate

Candidate package: `Darkstalkers - The Night Warriors (US).uac`.

The source Redump ZIP uses `(USA)` in its filename. The package uses the
agreed two-letter region spelling `(US)`. The full source ZIP, BIN/CUE
extraction, and study evidence remain in AudioMan's PlayStation source-study
folder. The original CUE is included byte-for-byte and Redump DAT verification
is included as a concise TSV attachment.

The package has 48 members: 45 playable APE tracks, the CUE, this tag-surface
README, and the Redump verification TSV. APE members and their `originalName`
values use neutral sequence filenames `01.ape` through `45.ape`; the prior
derived filenames were placeholders, not source names. The APE bytes match
the prior verified lossless transcodes.
Physical disc tracks 02–46 are represented in CUE order; the 212-second silent
last track is retained.

## Proposed/applied tag surface

Every playable member has these populated direct Title Case fields:

| Tag | Value/source |
| --- | --- |
| Album | `Darkstalkers - The Night Warriors`; release title without region, per PSX profile. |
| Platform | `PSX`; canonical system identifier. |
| Format | `Red Book CD-DA`; source format in one concise field. Structural UAC `member.format` remains `ape`. |
| Disc Number | `1`; normalized from the source APE `Discnumber` tag. |
| Track Number | `1`–`45`; normalized from each source APE `Tracknumber` tag. The CUE remains the authority for physical tracks 02–46. |

Package-level fields are **Game ID** `Darkstalkers - The Night Warriors
(US)`, **Region** `US`, **Set Collection** `Redump`, **Set Name** `Sony
PlayStation 1 Redump Set Collection (Part 1/4)`, and **Set URL** `https://archive.org/details/ef_Sony_PlayStation1_Redump_Collection_1of4`. The CUE, README, and verification TSV are ordinary package attachments, not pseudo-tags. Duration is omitted: APE frames and CUE provide what
the player needs to decode and order these tracks, and a stored millisecond
readout is not a playback instruction.

The source APE members contain only Disc and Track numbers. Their APE/CUE data
has no track title, artist, composer, publisher, or developer values. Those
fields are omitted rather than fabricated. No blank tags, `NativeMetadata`,
CD-DA sample-format facts, pregap/sector fields, fake track titles, or negative
loop markers are emitted. The ordered playlist stores only member pointers.

## Integrity and validation

Each physical APE member retains the standard UAC member-integrity hashes
(BLAKE3-256, CRC32, SHA-1, and MD5). The package has no second
`playable-payload` hash list and no decoded-PCM hash table. The source record
retains the four previously established archive hashes; Redump's source
BIN/CUE checksums remain in the attached TSV.

`uacman inspect --verify` confirmed payload integrity. A complete unpack/readback
confirmed 48 members, 45 APE tracks with standard UAC member hashes only, exact
source APE and CUE bytes, 45 ordered playlist entries, no duplicate
`playable-payload` hash lists, no `NativeMetadata` or duration/stat tags, and
the tag list above. This report documents the concrete package's field choices;
the PSX profile remains the evergreen policy.
