# Nintendo Sound Format (NSF) Profile

Apply the [UAC Base Profile](BASE-UAC-PROFILE.md) and
[Compact Pre-Disc Native Procedure](PRE-DISC-NATIVE.md). This profile covers
`.nsf` members only. `.nsfe` is a separate format and is excluded even when
both formats occur in one source archive. Platform identity comes from
verified source or database evidence, never from the NSF signature alone.
See [`MetaMan/format-layouts.md`](../../MetaMan/format-layouts.md).
The fixed header follows the [NESdev NSF format](https://www.nesdev.org/wiki/NSF);
playlist rows follow the
[NSFPlay distribution notes](https://github.com/bbbradsmith/nsfplay/blob/master/distribute/nsfplay.txt).

## Scope

- **Reader** — MetaMan's fixed-header NSF reader; companion M3U parsing is a
  required part of the UAC workflow.
- **Members** — One physical `.nsf`, its applicable byte-exact `.m3u`
  playlists, and any useful source documents belonging to that NSF.
- **Track model** — Store the physical NSF once; represent its songs as
  ordered playlist entries pointing to that member. Never fabricate a
  separate audio file for a subsong.
- **Status** — Proposed. Hold UAC creation until the parser and projection
  blockers in Required Checks are resolved and reviewed against fixtures.

## Field Mapping

| Source field | UAC field | UAC coded location | Rule |
| --- | --- | --- | --- |
| Verified game identity | Game ID | `game.metadata["Game ID"]` | Keep a verified No-Intro release identity separate from source titles. A title-root match alone does not establish region or revision. |
| NSF header `game` | Game Title | `game.metadata["Game Title"]` | Preserve a populated source value. Do not rename it Album or replace it with Game ID. |
| NSF header `artist` | Album Artist | `game.metadata["Album Artist"]` | Shared source credit; omit blank and placeholder values. Do not copy it to every track. |
| NSF header `copyright` | Copyright | `game.metadata["Copyright"]` | Preserve when populated; omit empty and placeholder values. |
| NSF header `comment` | Comment | `game.metadata["Comment"]` | Preserve only useful populated source text. Do not turn parser notices or generated text into tags. |
| NSF header version byte | Format | `playlists[].entries[].extraFields["Format"]` | Put `NSF v.1` or `NSF v.2` on each logical track. Read the exact byte from that NSF; never normalize versions. |
| M3U row title | Title | `playlists[].entries[].title` | Keep the authored title for the referenced song. Do not invent `Track N` titles. |
| M3U play time | Play Length (ms) | `playlists[].entries[].extraFields` | Convert a positive authored time to integer milliseconds without dropping fractional seconds. Missing, invalid, and zero values stay absent. |
| M3U loop duration | Loop Length (ms) | `playlists[].entries[].extraFields` | Use only a valid positive authored duration. A dash meaning no loop creates no tag. |
| M3U loop-start time (`h:m:s-`) | Intro Length (ms) | `playlists[].entries[].extraFields` | Preserve the authored loop start as the length of the intro before the loop. Do not invent a separate `No Loop` or loop-start tag. |
| M3U fade time | Fade Length (ms) | `playlists[].entries[].extraFields` | Convert a positive authored value to integer milliseconds. Missing or zero values stay absent. |
| `# Music by` or `# Composer:` | Composer | `game.metadata["Composer"]` | Keep only populated, explicit credits. Do not confuse these with the NSF shared `artist` field. |
| `# Ripped by` or `# Ripper:` | Dumper | `game.metadata["Dumper"]` | Keep the source role as Dumper; omit blank or placeholder values. |
| `# Tagged by` and `# Updated by` | Taggers | `game.metadata["Taggers"]` | Retain populated names as a list; de-duplicate exact repeats without merging distinct people. |
| `# Developed by` | Developer | `game.metadata["Developer"]` | Keep only explicit populated values. |
| `# Published by` | Publisher | `game.metadata["Publisher"]` | Keep only explicit populated values. |
| `# Published in` | Year or Date | `game.metadata["Year"]` or `game.metadata["Date"]` | Use Year for a year-only value and Date for a full source date. Keep ambiguous or multi-year strings in the M3U attachment and route them to review. |

Decimal NSF M3U song numbers are one-based; map `n` to UAC's zero-based
`trackIndex = n - 1`. If a row uses the `$hex` index form, it is already
zero-based and maps directly. Preserve playlist order and repeated rows.
Parse escaped commas in titles as data, not additional columns. Keep loop
count in the original playlist attachment; it is not a surfaced metadata tag.

## Format Procedures

- **Hashes** — Retain the four compact native-stream hashes required by the
  shared pre-disc procedure for each physical NSF member: BLAKE3-256, CRC32,
  SHA-1, and MD5. Reuse stored measurements only after matching current member
  bytes. Hash once per NSF, not once per playlist row. These are UAC integrity
  records, not tag names.
- **M3Us** — Preserve applicable source M3Us byte-for-byte as package
  attachments with their original names and paths. They contain authored
  titles and playback timings, so they are not disposable queues. Resolve
  every member reference exactly. Hold an archive when a playlist refers to
  NSFE or another unresolved member rather than copying it into the NSF
  package.
- **Shared tags** — Set Name, Set URL, Game Title, Game ID, Album Artist,
  Dumper, Taggers, and other source-backed package fields belong at package
  scope when they describe that package. Track Title and authored playback
  fields belong to the corresponding logical track. Do not repeat package
  fields on every track.
- **Unhelpful values** — Omit empty values, `<?>`, `Unknown`, generated
  playlist-tool notices, header implementation details, and diagnostic
  statistics. Do not surface raw lower-case M3U keys or create tags solely to
  mirror parser fields.
- **Conflicts** — If header, M3U, or comment values disagree, retain all
  source bytes and route the package to review. Do not choose one value,
  flatten a list, or promote a comment automatically.
- **Versions and validity** — The supported NSF header version bytes are 1
  and 2. Preserve each exact value in Format. A version-zero or otherwise
  invalid header requires review; only confirmed critical faults receive
  `Status: Corrupt`. Use `Status: Mixed Versions` only when a single proposed
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
- **M3U resolution** — Parse the documented `filename::NSF,song,title,time,
  loop,fade,loopcount` form, escaped commas, fractional time precision,
  one-based decimal song numbers, and zero-based `$hex` song indexes. Confirm
  each row resolves to the exact NSF member and an in-range song.
- **Ambiguity** — Compare all M3Us for the same member and song. Conflicting
  titles or timing, malformed columns, unresolved references, and uncertain
  loop meaning stay in the nested per-set review report.
- **Metadata scope** — Confirm package credits are not repeated as track
  credits, no default timing or empty tags appear, and Format is visible on
  every logical track.
- **UAC review** — Confirm each physical NSF appears once, its four hashes are
  visible in Stream Hashes, applicable M3Us/text remain attached, and no
  outer `.7z` is embedded. Verify the manifest in UACMan before treating a
  conversion as complete.
- **Parser hold** — The current MetaMan NSF reader reads the fixed header but
  does not consume companion M3Us and supplies a 150,000 ms default play
  length. Remove that fallback from UAC output and implement the M3U mapping
  above before creating packages.
