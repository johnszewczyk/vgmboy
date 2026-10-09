# Game Boy Sound System · GBS Profile

Apply the [UAC Base Profile](BASE-UAC-PROFILE.md) and
[Compact Pre-Disc Native Procedure](PRE-DISC-NATIVE.md). GBS is a compact
Game Boy music container; one physical `.gbs` file may expose several logical
tracks. MetaMan reads its fixed header and can use NEZplug extended-M3U
sidecars. See [`MetaMan/format-layouts.md`](../../MetaMan/format-layouts.md).
The native header fields and version byte follow the
[GBS format definition](https://github.com/mmitch/gbsplay/blob/master/gbsformat.txt).

## Scope

- **Reader** — `gbs`; `GameMusicMetadataReader.swift` and
  `GBSM3UMetadataReader.swift`.
- **Source members** — `.gbs`; optional companion `.m3u` files.
- **Coverage** — GBS header game, artist, and comment fields; M3U track rows
  and recognized `# @KEY value` comments.
- **Status** — Draft. The current reader drops fractional M3U timing and picks
  one of conflicting M3U rows; retain raw rows and hold those cases until the
  conversion path preserves them.

## Field Mapping

| Source Tag | UAC Tag | UAC Coded Tag | Tag Notes |
| --- | --- | --- | --- |
| GBS header `game` | Album | `game.metadata["Album"]` | One nonempty, shared value for the physical GBS file. Do not substitute a filename or an inferred DAT title. |
| GBS header `artist` | Album Artist | `game.metadata["Album Artist"]` | Shared source value; do not duplicate it as track Artist. |
| GBS header copyright string (MetaMan exposes `comment`) | Copyright | `game.metadata["Copyright"]` | This fixed header slot is the format's copyright field; preserve its populated value as written. |
| M3U `# @TITLE value` | Album | `game.metadata["Album"]` | Use only when all applicable rows agree; otherwise retain the header value and route the conflict to review. |
| M3U `# @ARTIST value` | Album Artist | `game.metadata["Album Artist"]` | Use only when the value is shared and unambiguous. |
| M3U `# @DATE value` | Date | `game.metadata["Date"]` | Keep the source value; do not infer a date from a filename or composite track title. |
| M3U `::GBS,index,title,...` title | Title | `playlists[].entries[].title` | Source track title, retained as written. Do not split embedded composer, game, publisher, or copyright text out of the title. |
| M3U source index | Playlist `trackIndex` | `playlists[].entries[].trackIndex` | GBS indexes are zero-based, including hexadecimal indexes. Do not create a second Track Number tag. |
| M3U time, loop, fade, repeat columns | Playlist entry timing fields | `lengthRaw`, `loopRaw`, `fadeRaw`, `repeatRaw` | Keep authored raw values and the original M3U bytes. Do not emit these as descriptive tags or replace missing/unparsed values with defaults. |
| GBS header version byte | Format | `playlists[].entries[].extraFields["Format"]` | Use `GBS v.<version>` on every logical track, for example `GBS v.1`. Read the byte from that physical member; never normalize versions. |

## Format Procedures

- **Platform identity** — Set structural `game.console` from a verified source
  system or canonical database match. GBS alone does not distinguish Game Boy
  from Game Boy Color; the version byte is not a platform identifier. Use the
  exact canonical aliases in
  [`PLATFORMS.md`](PLATFORMS.md); hold Super Game Boy labels when their
  platform meaning is unclear. Do not add a repeated Platform tag.
- **Physical file and subsongs** — Store each source `.gbs` once and point
  ordered playlist entries at it. Keep a one-track GBS as an explicit
  playlist entry too. Hash the physical member once, not once per subsong.
- **Format version** — Read version byte `0x03` for every physical GBS and
  surface it in each track's **Format** field. A set can contain v1, v2, or
  v4 files; do not flatten them to one version. Report multiple versions
  within a game/package and hold the affected package for review.
- **GBS header fields** — Validate the 112-byte fixed header, `GBS` signature,
  nonzero version and track count, and the declared first-track index. Keep
  load/init/play addresses and timer bytes as validation evidence only; do
  not promote them to user-facing tags.
- **M3U files** — Preserve every source M3U byte-for-byte as a package
  attachment, including multiple M3Us that refer to the same GBS. Their rows
  can carry track names and playback timing, so they are not disposable
  generated queues. Preserve original names and paths in source provenance.
- **M3U row conflicts** — Compare all rows for the same GBS member and
  zero-based index. If titles or timings disagree, retain the competing rows
  and route the track/package to review. Do not silently select the richest
  row, merge rows, or treat a second title as a duplicate without evidence.
- **Timing** — M3U timing is playback data, not a metadata tag. Preserve raw
  play, loop, fade, and repeat values in playlist-entry fields. The current
  MetaMan reader accepts integer colon components only; fractional times and
  some loop values are lost. A 150-second reader fallback is not source data
  and must never be written to UAC. Keep the original M3U and hold affected
  rows until raw timing is represented losslessly.
- **Composite titles and comments** — Keep a composite M3U title as one Title
  value. Promote a recognized, populated `# @KEY` value only through an
  explicit useful-field mapping in Title Case. Do not turn freeform comments,
  unknown keys, or parser diagnostics into new tags; retain useful narrative
  in the original M3U attachment.
- **Other members** — Inspect each non-GBS member. A `.gbs` suffix is not proof
  of GBS data; a missing signature or an identified ROM is a format mismatch
  for review, not a valid track. Preserve valid companion data and report
  unexplained or foreign members instead of silently dropping them.
- **Hashes** — Apply the four compact pre-disc hashes to each physical GBS
  stream under the shared procedure. Keep these as UAC integrity/source
  identity records, not invented tag keys.

## Required Checks

- **Header and version** — Check every physical `.gbs` signature, header
  length, version byte, declared track count, first index, and nonempty
  identity fields. Record version counts and identify mixed-version games.
- **Playlist mapping** — Resolve every M3U row to one member and an in-range
  zero-based track index. Preserve order, repeated indexes, raw row text, and
  all sidecars; report missing, duplicate, or conflicting references.
- **Timing fidelity** — Compare source timing strings with UAC playlist
  entries. Confirm fractional seconds, unusual loop values, repeat counts, and
  absent values survive without integer truncation or a 150-second fallback.
- **Tag scope** — Confirm Album and Album Artist are shared only when their
  source values agree, track titles remain attached to the correct index, and
  no empty, inferred, or diagnostic tags were added.
- **UAC review** — Verify Format is visible on each track, hashes are visible
  in Stream Hashes, and source M3Us remain available as package attachments.
  Keep this profile Draft until fixture and GUI visibility checks pass.
