# Nintendo Sound Format (NSF) Profile

Apply the [UAC Base Profile](BASE-UAC-PROFILE.md) and
[Compact Pre-Disc Native Procedure](PRE-DISC-NATIVE.md). This profile covers
`.nsf` members only. `.nsfe` is a separate format; if present in the same
source package, retain it as a non-playable asset. Platform identity comes from
verified source or database evidence, never from the NSF signature alone.
See [`MetaMan/format-layouts.md`](../../MetaMan/format-layouts.md).
The fixed header follows the [NESdev NSF format](https://www.nesdev.org/wiki/NSF);
playlist rows follow the
[NSFPlay distribution notes](https://github.com/bbbradsmith/nsfplay/blob/master/distribute/nsfplay.txt).

## Scope

- **Reader** — MetaMan reads the fixed NSF header and NSFPlay extended-M3U
  rows. UACMan projects those rows into its native playlist entries.
- **Members** — One physical `.nsf`, its applicable byte-exact `.m3u`
  playlists, and any useful source documents belonging to that NSF.
- **Track model** — Store the physical NSF once; represent its songs as
  ordered playlist entries pointing to that member. Never fabricate a
  separate audio file for a subsong.

## Field Mapping

| Source field | UAC field | UAC coded location | Rule |
| --- | --- | --- | --- |
| Verified No-Intro game identity | Game ID | `game.metadata["Game ID"]` | Store the canonical DAT title root as a string. Keep numeric DAT IDs in AudioMan only; the root does not establish region or revision. |
| NSF header `game` | Game Title | `game.metadata["Game Title"]` | Preserve a populated source value. Do not rename it Album or replace it with Game ID. |
| NSF header `artist` | Album Artist | `game.metadata["Album Artist"]` | Shared source credit; omit blank and placeholder values. Do not copy it to every track. |
| NSF header copyright slot (`0x4E..0x6D`) | Copyright | `game.metadata["Copyright"]` | The NSF header's third 32-byte text field is copyright, not a separate comment. Preserve when populated; omit empty and placeholder values. |
| NSF header version byte | Format | `playlists[].entries[].extraFields["Format"]` | Put `NSF v.1` or `NSF v.2` on each logical track. Read the exact byte from that NSF; never normalize versions. |
| M3U row title | Title | `playlists[].entries[].title` | Keep the authored title for the referenced song. Do not invent `Track N` titles. |
| M3U play time | Play Length (ms) | `playlists[].entries[].extraFields` | Convert a positive authored time to integer milliseconds without dropping fractional seconds. Missing, invalid, and zero values stay absent. |
| M3U loop duration | Loop Length (ms) | `playlists[].entries[].extraFields` | Use only a valid positive authored duration. `loopRaw` also retains the player-facing authored value. A dash or zero meaning no loop creates no tag. |
| M3U loop-start time (`h:m:s-`) | Intro Length (ms) | `playlists[].entries[].extraFields` | Keep the exact authored value, including its trailing `-`, in `loopStartRaw`; parse the prefix as the intro length. Do not invent a separate `No Loop` or loop-start tag. |
| M3U fade time | Fade Length (ms) | `playlists[].entries[].extraFields` | Convert a positive authored value to integer milliseconds. Missing or zero values stay absent. |
| M3U `Music by` comment | Composer | `game.metadata["Composer"]` | Keep populated explicit credits. Filter blank and placeholder values. |
| M3U `Ripped by` / `Ripper` comment | Dumper | `game.metadata["Dumper"]` | Preserve the source role as Dumper; do not rename it Ripper or Encoded By. |
| M3U `Tagged by` / `Updated by` comments | Taggers | `game.metadata["Taggers"]` | Preserve distinct exact values as a list; do not split or rewrite a source credit string. |
| M3U `Developed by` comment | Developer | `game.metadata["Developer"]` | Keep populated explicit values. |
| M3U `Published by` comment | Publisher | `game.metadata["Publisher"]` | Keep the explicit publisher value. |
| M3U `Published in` comment | Year / Date and Publisher | `game.metadata["Year"]`, `game.metadata["Date"]`, `game.metadata["Publisher"]` | Extract a single unambiguous year or full date and any explicit `by ...` publisher. Multiple years stay attached and are reported for review. |
| M3U `Copyright` comment | Copyright | `game.metadata["Copyright"]` | Promote only when no populated NSF-header or playlist copyright conflicts with it. Hold disagreements for review. |
NSFPlay M3U song numbers are decimal and one-based; map `n` to UAC's
zero-based `trackIndex = n - 1`. Preserve authored order and repeated rows.
Parse escaped commas in titles as data, not additional columns. Fractional
seconds are rounded half-up to milliseconds for readable metadata while the
exact raw values and source row remain in the manifest and original M3U.
`loopcount` is carried as UAC's native `repeatRaw`, never as a surfaced tag.
Keep the raw `lengthRaw`, `loopRaw`, `loopStartRaw`, `fadeRaw`, and `repeatRaw`
values for playback-aware readers; the millisecond fields are the readable
metadata projection, not replacements for the source semantics. If the M3U
omits a track time, leave Play Length absent. Missing time does not itself
mean “play forever”; actual end-of-track behavior belongs to the playback core.

## Format Procedures

- **Hashes** — Retain the four compact native-stream hashes required by the
  shared pre-disc procedure for each physical NSF member: BLAKE3-256, CRC32,
  SHA-1, and MD5. Reuse stored measurements only after matching current member
  bytes. Hash once per NSF, not once per playlist row. These are UAC integrity
  records, not tag names.
- **M3Us** — Preserve source M3Us byte-for-byte as package attachments. The
  same-stem aggregate M3U is the playback-order authority. Keep per-track
  sidecar M3Us as evidence and compare them for conflicts; never concatenate
  their rows into the playable queue. Resolve exact `.nsf` references, plus
  extensionless stems only when they identify this sole NSF unambiguously.
  Flag references to other files for review. When a source archive also
  contains `.nsfe`, preserve it as an `asset`; this NSF pass does not expose
  its songs as NSF tracks.
- **Shared tags** — Set Name, Set URL, Game Title, canonical-root Game ID, Album Artist,
  Dumper, Taggers, and other source-backed package fields belong at package
  scope when they describe that package. Track Title and authored playback
  fields belong to the corresponding logical track. Do not repeat package
  fields on every track.
- **Unhelpful values** — Omit empty values, `<?>`, `Unknown`, generated
  playlist-tool notices, freeform playlist-title comments, header
  implementation details, and diagnostic statistics. Only the explicit M3U
  comment labels in Field Mapping become package tags. Do not surface raw
  lower-case M3U keys or create tags solely to mirror parser fields.
- **Conflicts** — If header, aggregate M3U, or sidecar comment values disagree,
  retain all source bytes, omit the ambiguous canonical value, and route the
  package to the set's dashboard review report. Never choose one value or
  collapse a source list. Invalid timing fields and malformed rows are also
  reported without substituting values.
- **Versions and validity** — The supported NSF header version bytes are 1
  and 2. Preserve each exact value in Format. A version-zero, unsupported
  version, invalid track count, or out-of-range first-song index requires
  review; only confirmed critical faults receive `Status: Corrupt`. Use
  `Status: Mixed Versions` only when a single proposed
  game package actually contains mixed NSF versions. Never add `Status: Good`.
- **Side documents** — Preserve useful source text as `meta.txt`, keeping its
  bytes unchanged. Do not mine freeform notes into tags. Patches such as IPS
  are not NSF tracks; hold an archive containing one for review rather than
  applying or silently dropping it.
- **Source archive boundary** — Do not embed the outer source `.7z` inside a
  UAC or create a `Source Encoding` tag. The set profile governs source
  identity and URL. Source-state archive hashes are not file tags unless a
  separate source-set rule explicitly requires them.

## Required Checks

- **Header** — Validate the 128-byte fixed header, `NESM\x1A` signature,
  version byte, declared track count, first-song index, and all bounds.
  Header load/init/play addresses remain validation evidence, not tags.
- **M3U resolution** — Parse `filename::NSF,song,title,time,loop,fade,
  loopcount`; track 1 is the first song. Preserve exact raw loop-start syntax
  and flag non-empty invalid timing/count fields. A loop value of `h:m:s` is a loop
  duration, `h:m:s-` is the loop start, and `-` or `0` means no loop. A loop
  count of `0` means player default. Check every selected row against the
  exact NSF member and declared song count. Preserve primary-list order and
  repeats, then append any header songs missing from a partial list without
  invented titles or timings.
- **Ambiguity** — Compare all M3Us for the same member and song. Conflicting
  titles or timing, malformed columns, unresolved references, and uncertain
  loop meaning stay in the nested per-set review report.
- **Metadata scope** — Confirm package credits are not repeated as track
  credits, no default timing or empty tags appear, and Format is visible on
  every logical track.
- **UAC review** — Confirm each physical NSF appears once, its four hashes are
  visible in Stream Hashes, applicable M3Us/text remain attached, and no
  outer `.7z` is embedded. Check `originalMemberPath`, raw M3U row and timing
  fields, readable millisecond fields, `Format: NSF v.N`, and that absent
  source timings stay absent. Verify the manifest and playback entries in
  UACMan before treating a conversion as complete.
