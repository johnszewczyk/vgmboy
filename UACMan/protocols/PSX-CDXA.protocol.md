# PSX CD-XA preservation protocol

This protocol defines the canonical conversion path for PlayStation Redump
discs whose music is stored as CD-XA sectors. The result is a playable UAC
package containing the exact native XA sector members and, when present, a
Redbook/CD-DA track encoded as APE Insane. The disc's loop decisions and
source identity are retained as machine-readable metadata. The original
Redump BIN/CUE remains the immutable source of truth; the UAC is a derived
playback package.

## Authority and source boundary

Use a verified Redump BIN and its matching CUE. Record the BIN and CUE
BLAKE3-256 (and any available SHA-1/MD5) in the UAC source object. Preserve the
source archive identity and retrieval URL. Do not infer loop points from a
third-party rip, filename, or decoded waveform when the game has a native
playback table.

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

Extract every disc-native XA stream as the exact selected 2352-byte sectors,
preserving XA headers, subheaders, interleave order, and source sector
boundaries. Hash every resulting member and require equality with the source
BIN-derived stream hash. Extract each audio track named by the CUE as its own
source-state member; for a Redbook/CD-DA track, decode to PCM and encode one
APE Insane member. Verify that APE with `mac -V` and compare decoded PCM
BLAKE3-256 plus byte count. The native XA members remain byte-reconstructible
from the source sectors; only the Redbook member is transcoded.

For XA members, the extracted XA bytes are the canonical stream. The member
`blake3` and the source-XA BLAKE3 are therefore the identity hash; a separate
`streamBlake3` is redundant and may be omitted. If retained for compatibility,
it must equal the raw-XA digest and identify the `raw-member-v1` profile. The
Redbook APE has a distinct stored-member hash and may additionally carry a
`decoded-pcm-v1` hash with its PCM parameters. Documentation and cue members
have no stream hash because they are not audio streams. This is a source-state
rule, not a claim that every audio format has a meaningful rendered-stream
hash.

Useful source tags and researched fields are represented in the UAC member
metadata. Generic loop fields are replaced with the disc-native values where a
native mapping exists; streams without a native mapping carry an explicit
no-loop provenance. `TXTP_*`, JoshW-specific, and other external-loop fields
are excluded from the canonical package. External comparisons belong in
research records, never in playable member metadata.

Keep set-level provenance in `sources[]` or `game.metadata`; do not repeat it
on every track. In particular, the source archive hash, BIN hash, CUE hash,
download URL, source format, and region do not need per-track copies. A track's
sector range, native loop mapping, track number, title, and stream identity are
track facts. Avoid duplicate spellings such as `discFilename` plus
`ON_DISC_NAME`, `sourceBinBlake3` plus `SOURCE_BIN_BLAKE3`, or a `sourceXA`
object plus the same values in flattened tags. Keep one canonical structured
field and retain the full raw research report as a documentation member.

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

For a transcoded Redbook member, APE tags mirror its source evidence. For XA,
the UAC member object is authoritative because the native sector file has no
general-purpose tag block. The loop object is also repeated in the playlist
for players that consume ordered UAC entries.

Include the original CUE as a byte-exact ordinary member and point to it with
`game.metadata.cue_sheet`. Include the native loop report, the certification
list, the duration-candidate report, XA sector inventory, and source manifest as
documentation members. Set-level metadata uses the shared
shape `game.metadata.set = {collection, name, url}`. A playlist points to each
APE member and repeats the loop fields needed by a player UI; it does not copy
the audio payload.

Do not duplicate the full BIN/CUE source inside the UAC unless a future
package explicitly elects to be self-contained. Source hashes and the source
package identity are sufficient for this derived package, while the verified
source remains available in the source-state tree.

## OST title matching

Official OST durations are evidence for candidate labels only. Match by
duration after accounting for the native loop body, but do not automatically
rename or retag a stream when multiple OST tracks share the same duration or
when no candidate is close. Publish a Markdown certification list with the
current stream filename, native loop interval, duration candidates, and an
explicit status (`clear`, `ambiguous`, `no-clear-match`, or `no-native-loop`).
Human certification can later promote a title into the authored metadata.

## External-rip comparison

JoshW material is a comparison fixture, never loop authority. Compare its XA
members to the Redump extraction at the raw sector/channel level and record
byte-identical, missing, and differing members. Compare its TXTPlay loop
values against the independently derived native values. Differences are
evidence to investigate; they do not change the native UAC tags.

## Required validation

Before publishing a package:

1. Verify the Redump source archive, BIN, and CUE hashes.
2. Confirm every staged APE passes `mac -V` and PCM BLAKE3 equality.
3. Run `uacman inspect --verify` and a payload read/unpack check.
4. Confirm the UAC has every intended native XA member, the Redbook APE, the
   CUE, and documentation members; no `.DS_Store`, BIN, TXTP, or unrelated
   source archives are admitted.
5. Confirm native loop metadata is present at both member and playlist levels,
   and that unresolved/no-loop streams remain documented.

This protocol is the format-specific companion to the general UAC wrapper
contract in `ai/subsystem-agent/uac-wrapper-format.md`.
