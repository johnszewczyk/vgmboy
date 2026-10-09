# Game Boy Sound System · GBS Profile

Apply the [UAC Base Profile](BASE-UAC-PROFILE.md) and
[Compact Pre-Disc Native Procedure](PRE-DISC-NATIVE.md). GBS is a compact
Game Boy music container; one physical `.gbs` file may expose several logical
tracks. MetaMan reads its fixed header and can use NEZplug extended-M3U
sidecars. See [`MetaMan/format-layouts.md`](../../MetaMan/format-layouts.md).
The native header fields and version byte follow the
[GBS format definition](https://github.com/mmitch/gbsplay/blob/master/gbsformat.txt).

## Scope

- **Metadata reader** — MetaMan's `gbs` reader parses the fixed GBS header and
  optional extended-M3U rows. The current VGMBoy playback registry supports
  `.gbs` through libgme. Neither current application reader supports `.gbr`,
  `.mgb`, or general `.gb` ROMs.
- **Source members** — `.gbs`; optional companion `.m3u` files.
- **Coverage** — GBS header game, artist, and comment fields; M3U track rows
  and recognized `# @KEY value` comments.
- **Status** — Profile rules complete; conversion is held until timing and
  competing M3U rows survive the reader-to-UAC path. MetaMan now converts
  fractional play, loop, and fade times to integer milliseconds; it still
  chooses one richest row when rows conflict. Retain the original M3U and do
  not certify conflicting projections as lossless.

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
| M3U time, loop, fade columns | Playlist entry extra fields | `Play Length (ms)`, `Loop Length (ms)`, `Fade Length (ms)` | Convert fractional final time components to integer milliseconds. Keep the original M3U attachment as the byte-exact source of authored strings. Missing or invalid times stay absent. Repeat-count values currently remain available in the M3U attachment and are not projected as entry fields. |
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
- **Identity and platform** — A GBS signature identifies the container, not
  whether the music belongs to Game Boy or Game Boy Color. Use source
  platform evidence and the format-agnostic No-Intro identity workflow; hold
  titles that resolve differently across the GB and GBC DATs for review. A
  unique title-root suggestion is not by itself a regional/revision Game ID.
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
- **Timing** — M3U timing is playback data attached to the logical track.
  MetaMan converts play, loop, and fade values, including a fractional final
  component with up to millisecond precision, to integer milliseconds for
  playlist entry fields. The source M3U attachment preserves authored strings
  and repeat counts. Invalid or absent timing stays absent; GBS header-only
  tracks have no known duration and must not receive a 150-second fallback.
- **Composite titles and comments** — Keep a composite M3U title as one Title
  value. Promote a recognized, populated `# @KEY` value only through an
  explicit useful-field mapping with canonical Title Case tag names. Do not
  surface raw lower-case source keys, empty values, freeform comments, unknown
  keys, or parser diagnostics as UAC tags; retain the original M3U attachment.
- **Related but separate members** — These are not GBS tracks and must not be
  folded into a GBS package or counted as GBS duplicates:

  | Member | Identification | Handling |
  | --- | --- | --- |
  | `.gbr` | Older Game Boy music-dump format (`GBRF` signature) | Separate format and review; current VGMBoy/MetaMan readers do not support it. The independent [gbsplay project](https://github.com/mmitch/gbsplay) lists GBR support. |
  | `.mgb` | Paragon 5 GameBoy Tracker module (`GameBoy Music Module` marker) | Separate tracker format and review; current VGMBoy/MetaMan readers do not support it. See [Paragon 5 tracker files](https://gbdev.gg8.se/files/musictools/Paragon5/). |
  | `.gb` | Raw Game Boy ROM image | ROM, not a GBS music container; route to ROM review. gbsplay supports only a subset as music, which is not support in our current reader. |

  Validate content signatures, not suffixes. A `.gbs`-named member that lacks
  the `GBS` signature (including a ROM image) is an extension/content
  mismatch for review, not a playable GBS track. Preserve the source archive
  and report the member instead of silently dropping it.
- **Hashes** — Apply the four compact pre-disc hashes to each physical GBS
  stream under the shared procedure. Keep these as UAC integrity/source
  identity records, not invented tag keys.

## Required Checks

- **Header and version** — Check every physical `.gbs` signature, header
  length, version byte, declared track count, first index, and nonempty
  identity fields. Record version counts and identify mixed-version games.
- **Format boundary** — Inventory `.gbr`, `.mgb`, and `.gb` members separately;
  confirm they are not counted as GBS tracks or silently discarded. Treat a
  mismatched `.gbs` suffix as a review item.
- **Playlist mapping** — Resolve every M3U row to one member and an in-range
  zero-based track index. Preserve order, repeated indexes, raw row text, and
  all sidecars; report missing, duplicate, or conflicting references.
- **Timing fidelity** — Compare source timing strings with UAC playlist
  entries. Confirm fractional seconds and unusual loop values convert without
  truncation, repeat counts remain available in the source M3U attachment, and
  absent values stay absent without a 150-second fallback.
- **Tag scope** — Confirm Album and Album Artist are shared only when their
  source values agree, track titles remain attached to the correct index, and
  no empty, inferred, or diagnostic tags were added.
- **UAC review** — Verify Format is visible on each track, hashes are visible
  in Stream Hashes, and source M3Us remain available as package attachments.
  Keep affected conversions held until competing M3U rows are preserved;
  verify fixture behavior and GUI visibility before treating the implementation
  as approved.
