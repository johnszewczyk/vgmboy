# PSX CD-XA preservation protocol

This protocol covers XA extraction and game-specific loop research for
PlayStation Redump discs. It does not define the visible PSX track-tag
vocabulary or require a UAC package for every soundtrack; those decisions live
in the [PSX disc-audio profile](../Procedures/PSX-CDXA.md). Treat the sector and
loop details here as operational source evidence, not as a list of music tags.
The original Redump BIN/CUE remains the source of record.

## Authority and source boundary

Use the declared Redump BIN and its matching CUE. Record the Redump release
identity and URL plus the published checksums for the original BIN once in the
package source record. Keep the original CUE as a byte-exact package member
when making a UAC. Reuse exact-scope checksum records already in the database;
do not add per-track hash arrays or repeat disc facts on each member. Do not
infer loop points from a third-party rip, filename, or decoded waveform when
the game has a native playback table.

For SOTN, the authoritative loop source is the disc's `DRA.BIN`
`XaMusicConfig` table and the game playback code. A native loop pair consists
of a config record and its continuation record. Convert the continuation's
physical XA sector to the decoded sample position using the XA frame sample
count (2016 samples at 37,800 Hz). The resulting interval is half-open:
`startSamples` is included and `endSamples` is excluded.

The native report must retain, for each mapped stream, the config indexes,
continuation index, physical LBA, sector index, loop start/end samples, source
stream identity, and mapping status. Unresolved records remain unresolved;
they are never filled from an external rip.

## Audio conversion

Extract each disc-native XA stream from its selected 2352-byte sectors,
preserving the source representation needed by the decoder and any verified
loop mapping. Extract each audio track named by the CUE as its own member.
Red Book CD-DA may be kept as WAV or encoded losslessly as APE/FLAC when that
serves the chosen delivery. This profile does not require a second PCM hash,
per-track checksum catalog, or separate encode-verification report. The UAC
wrapper's standard integrity data remain governed by its own contract.

For XA members, the selected disc sectors define the extracted source stream.
Keep any sector-to-member mapping only where it is needed to explain a
playback or loop decision. Do not add a second `streamBlake3`, decoded-PCM
hash, or four-algorithm hash list as PSX music metadata. Keep Redump identity
and original BIN checksums once in the package source record. Wrapper member
integrity fields are not track tags.

Do not generate music tags from the disc filename, CUE track number, codec,
or reader defaults. APE/FLAC native tags and whether selected values are
mirrored into the UAC manifest are governed by the PSX disc-audio profile.

Generic loop fields are replaced with the disc-native values only where a
verified native mapping exists. A member with no loop has no `loop` object,
no `loopStatus`, and no `LOOP_TYPE=none`, `LOOP_PROVENANCE`, or equivalent
negative tag. Absence of a loop field means no loop was identified. Keep a
positive loop map in structured member metadata and the player playlist; do
not flatten it into duplicate `LOOP_*` tags.

For raw XA, MetaManCore's `nativeMetadata.technicalFacts` can describe the
reader's interpretation. Keep such facts out of the visible music-tag surface;
retain only the structured values a decoder, player, or verified loop mapping
actually needs. Do not duplicate them as `XA_*` tags. Suppress the reader's
generic `comment: Sony XA header` placeholder; it is not a source comment.
`TXTP_*`, JoshW-specific, and other external-loop fields remain in research
records, not playable member metadata.

Keep set-level provenance in `sources[]` or `game.metadata`; do not repeat it
on every track. Record the Redump identity and known source BIN checksums once.
The attached CUE carries its own track layout and indexes. A physical disc
track number may be needed to interpret a playlist, but that does not decide
which number belongs in visible music tags. Keep sector/loop mapping only when
it supports playback or source research. Do not duplicate structured values as
flattened tags or parallel spellings. Add research documents only when they
support a concrete source-mapping or review need.

## UAC member metadata

Every playable XA member with a native loop carries:

```json
{
  "loop": {
    "mode": "forward",
    "startSamples": 123,
    "endSamples": 456,
    "sampleRateHz": 37800,
    "repeat": "forever",
    "source": "sotn.dra.xa_music_config"
  }
}
```

For a Red Book member, use the native WAV/APE/FLAC tag interface as the
candidate track surface. The exact tags and any manifest synchronization
remain open under the PSX disc-audio profile. For XA, a UAC member object may
carry the positive loop mapping a player needs because a raw sector member has
no general-purpose tag block. Repeat a loop in the playlist only when the
player requires it.

Include the original CUE as a byte-exact ordinary member and point to it with
`game.metadata.cue_sheet`. Add loop or sector research documents only when
they support a concrete source-mapping or review need. Set identity uses the
shared `game.metadata.set` object. A playlist points to audio members and
contains playback fields only when a consumer needs them; it does not copy the
audio payload.

Do not duplicate the full BIN or downloaded archive inside the UAC unless a
future package explicitly elects to be self-contained. Keep the source BIN
checksums and Redump identity at package/source scope; the CUE attachment
documents the disc layout. The source files remain in the source-state tree.

## OST title matching

Official OST names and durations may support a separate title research task.
Do not promote candidate labels into track tags until the source and matching
decision are explicit. Keep unresolved candidates in research material.

## External-rip comparison

External rips are optional research material, not routine packaging inputs or
tag authority. Use them only for a specific unresolved title or loop question;
record candidates outside the ordinary track-tag surface.

## Required validation

When creating a UAC, identify the declared Redump source once, include the CUE,
and run the wrapper's normal package-integrity check. Keep the package's
intended audio members and avoid unrelated files. Verify positive XA loop
mapping when a package carries one. Do not require per-track hash arrays,
decoded-PCM comparisons, Red Book technical tags, or reader diagnostic tags as
part of this PSX profile.

This protocol is the format-specific companion to the general UAC wrapper
contract in `ai/subsystem-agent/uac-wrapper-format.md`.
