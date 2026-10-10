# Nintendo NES / Famicom Disk System · NSF / NSFE Profile

Apply the [UAC Base Profile](BASE-UAC-PROFILE.md) and
[Compact Pre-Disc Native Procedure](PRE-DISC-NATIVE.md). This profile covers
the Nintendo Entertainment System and Famicom Disk System source sets; the
platform comes from positive source or database evidence, not from the NSF
signature. See [`MetaMan/format-layouts.md`](../../MetaMan/format-layouts.md).

## Scope

- **Readers** — MetaMan's fixed-header NSF and chunk-based NSFE readers.
- **Source members** — `.nsf`, `.nsfe`, companion `.m3u`, and source text files.
- **Coverage** — NSF/NSFE game, artist, comment, copyright, ripper, notes,
  track labels/authors, authored timing, playlist order, and sound-effect
  indexes.
- **Status** — Proposed; do not convert until the parser and UAC projection
  blockers listed below are resolved and reviewed against the source fixtures.

## Field Mapping

### Package and member identity

| Source fact | UAC Tag | UAC Coded Tag | Tag Notes |
| --- | --- | --- | --- |
| Positive No-Intro release match | Game ID | `game.metadata["Game ID"]` | Store only a verified release identity. Keep it separate from the source `game`/`Album` value. |
| Source set identity | Set Name, Set URL | `game.metadata["Set Name"]`, `game.metadata["Set URL"]` | Preserve the exact set containing the source archive; recover from current source records when needed. Do not replace it with a parent collection label. |
| Verified platform | Structural platform | `game.console` | Use a name already present in `PLATFORMS.md`. Nintendo NES is listed; Famicom Disk System does not yet have a canonical alias there, so hold FDS package output until that name is resolved. Do not add a duplicate Platform or System tag. |
| NSF header version byte | Format | `playlists[].entries[].extraFields["Format"]` | Use `NSF v.<version>` from each physical member, such as `NSF v.1`. Do not normalize different versions. |
| NSFE container | Format | `playlists[].entries[].extraFields["Format"]` | Use `NSFE`. NSFE has no general numeric version field; do not invent `NSFE v.1` or treat its optional `NSF2` chunk as a container-version number. |

Keep one playable format in each UAC package. If a source archive contains
both `.nsf` and `.nsfe`, split them into separate packages while preserving the
source relationship and both sets of bytes. This is a format split, not a
reason to merge tracks between the files.

### NSF

| Source field | UAC Tag | UAC Coded Tag | Tag Notes |
| --- | --- | --- | --- |
| NSF header `game` | Album | `game.metadata["Album"]` | Preserve the populated source game name; do not substitute the No-Intro Game ID. |
| NSF header `artist` | Album Artist | `game.metadata["Album Artist"]` | Package-wide source credit; do not repeat it as track Artist. Omit empty or placeholder values such as `Unknown`. |
| NSF header `comment` | Comment | `game.metadata["Comment"]` | Preserve the source field as Comment; do not reinterpret its text as a date or publisher. |
| NSF M3U row title | Title | `playlists[].entries[].title` | Keep the authored title for the referenced song. Do not create a title from the filename. |
| NSF M3U row play, loop, and fade times | Playback fields | `playlists[].entries[].extraFields` | Preserve source-authored values only. Use Play Length (ms), Loop Length (ms), and Fade Length (ms) once the NSF M3U column semantics are parser-validated. Omit missing/zero values; never add a “No Loop” tag or a fallback duration. |

NSF header song numbers are one-based in M3U rows. UAC `trackIndex` is the
zero-based decoder index, so map M3U song number `n` to `trackIndex = n - 1`.
The header's first-song byte selects the default song; it is not a second
Track Number tag. Keep source order and do not fabricate titles or timing when
the NSF has no companion M3U.

### NSFE and companion M3U

| Source field | UAC Tag | UAC Coded Tag | Tag Notes |
| --- | --- | --- | --- |
| NSFE `auth` game | Album | `game.metadata["Album"]` | Preserve the populated source game name. |
| NSFE `auth` artist | Album Artist | `game.metadata["Album Artist"]` | Package-wide source credit; do not copy it onto each track. |
| NSFE `auth` copyright | Copyright | `game.metadata["Copyright"]` | Preserve only when populated. |
| NSFE `auth` ripper | Dumper | `game.metadata["Dumper"]` | Keep the source credit under Dumper, not Encoded By. |
| NSFE `text` notes | Comment | `game.metadata["Comment"]` | Preserve populated notes once at package scope; do not synthesize a second Comment from Copyright or Dumper. |
| NSFE `tlbl` label or M3U row title | Title | `playlists[].entries[].title` | Preserve the label on the referenced song. If both sources disagree, retain the files and route the package to review. |
| NSFE `taut` author | Artist | `playlists[].entries[].artist` | Track-specific credit only. Keep shared `auth` artist as Album Artist. |
| NSFE positive `time` or M3U play time | Play Length (ms) | `playlists[].entries[].extraFields["Play Length (ms)"]` | Use only positive source-authored timing; never use MetaMan's 150-second reader fallback. |
| NSFE positive `fade` or M3U fade time | Fade Length (ms) | `playlists[].entries[].extraFields["Fade Length (ms)"]` | Use only positive source-authored timing. |
| M3U loop column with validated meaning | Loop Length (ms) | `playlists[].entries[].extraFields["Loop Length (ms)"]` | Keep only an authored, meaningful loop value. Do not infer a loop from play length. |
| NSF M3U `# Tagged by` | Tagger | `game.metadata["Tagger"]` | Keep only a populated, consistent credit. `# Playlist generated by` is a tool note, not a Dumper or Tagger value. |
| NSF M3U `# Music by` | Album Artist | `game.metadata["Album Artist"]` | Use only when populated and unambiguous; omit `Unknown`. |
| NSF M3U `# Copyright` | Copyright | `game.metadata["Copyright"]` | Keep distinct from Album and Comment. |

NSFE track indexes are zero-based. Preserve `PLST` order and repeated source
indexes as separate playlist entries. Keep every M3U byte-for-byte as a
package playlist/asset with its original filename and source path; attach it
only to the exact referenced playable member and do not copy NSF playlists
into an NSFE package. A playlist may carry titles and authored timing, so it
is not a disposable generated queue. Do not collapse competing M3Us or choose
a richer row without source evidence.

### Package documents and non-music members

- Preserve one included source text document as `meta.txt`; if a package has
  several, use `meta-2.txt`, `meta-3.txt`, and so on. Record each original
  basename/path in provenance and keep its bytes unchanged. Do not mine
  freeform notes into invented tags.
- Channel-specific loop notes and approximations remain in the attached text
  document unless a source explicitly supplies one unambiguous track playback
  value. Do not average channel loops or turn an author's explanation into a
  guessed loop object.
- NSFE `PSFX` identifies source indexes marked as sound effects. Keep those
  findings in the set report/review workflow; do not create a generic SFX tag
  or mix flagged effect tracks into a clean music package without an explicit
  split supported by source indexes.
- Non-music members such as IPS patches are not playable NSF tracks. Preserve
  their source package for review; do not silently apply or discard a patch.

## Format Procedures

- **Hashes** — Use the four compact pre-disc hashes for each physical NSF or
  NSFE member: BLAKE3-256, CRC32/ISO-HDLC, SHA-1, and MD5. Reuse an existing
  stream-hash record only after matching the current bytes; otherwise hash the
  compact member once. Do not duplicate hashes per subsong.
- **Track model** — Store each physical NSF/NSFE once and model its songs as
  ordered playlist entries targeting that member. Do not create one member per
  song or add a redundant Track Number tag.
- **Format versions** — Record each NSF member's actual version byte in its
  tracks' Format field. Do not rewrite it. Report a game package with multiple
  NSF versions as `Status: Mixed Versions`. NSFE carries no generic numeric
  container version.
- **Metadata scope** — Album Artist, Dumper, Tagger, Set Name, and Set URL are
  package fields when shared and source-backed. Track Artist belongs only to
  `taut`/per-track authors. Keep empty, parser-default, technical, and
  diagnostic values out of tags.
- **SFX review** — Leave the Norbert NSF/NSFE source for the later SFX pass.
  For other sets, report PSFX-marked tracks and source packages with explicit
  mixed music/effect evidence before building the clean music packages.

## Required Checks

- **NSF header** — Validate the 128-byte header, signature, nonzero version and
  track count, first-song byte, and all member bounds.
- **NSFE chunks** — Validate INFO/DATA/NEND ordering and bounds, PLST/PSFX
  indexes, label/author indexes, and preservation of non-audio chunks.
- **M3U mapping** — Parse NSF M3U references by exact member path and
  one-based song number. Preserve fractional time precision to milliseconds.
  Route conflicting titles, timing, or loop values to review.
- **Fallback timing** — The current MetaMan NSF and NSFE readers supply a
  150,000 ms fallback when source timing is absent; the current projector would
  expose it as Play Length (ms). This must be removed from UAC projections
  before conversion. An absent source time stays absent.
- **Parser scope** — Current MetaMan does not enrich NSF from companion M3Us;
  its NSFE result also combines source scopes for some fields. Correct the
  mappings so NSF/NSFE game becomes Album, shared artist becomes Album Artist,
  ripper becomes Dumper, and per-track authors remain Artist.
- **Repeated NSFE indexes** — The UAC harvester currently rejects duplicate
  source indexes. Preserve valid repeated PLST entries before approving NSFE
  conversion.
- **Version and identity reports** — Inspect every source member's actual
  format/version and route mixed versions, mixed NSF/NSFE source archives,
  corrupt headers, M3U conflicts, SFX mixtures, and foreign members to the
  nested per-set dashboard report.
- **Current staged database state** — Current JoshW NES/FDS `.7z` rows are
  marked pending in Songbase with no member inventory. Reconcile the current
  byte set and source Set Name/URL before converting; do not treat retired
  archive-path rows as proof for these files.
