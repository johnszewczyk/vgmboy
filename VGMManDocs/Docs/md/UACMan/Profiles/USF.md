# Nintendo 64 · USF Profile

Apply the [UAC Base Profile](BASE-UAC-PROFILE.md),
[Pre-Disc Native Procedure](PRE-DISC-NATIVE.md), and, for set conversions, the
applicable [Base Set Profile](Sets/BASE-SET-PROFILE.md). MetaManCore and
AudioMan tools read Ultra64 Sound Format (USF and miniusf) `[TAG]` metadata
without starting an emulator. See
[`MetaMan/format-layouts.md`](../../MetaMan/format-layouts.md).

## Scope

- **Reader** — `psf-family` (`PSFMetadataReader.swift`) and `usf_uac_tag_surface.py`.
- **Source members** — `.miniusf`, `.usf`, and companion `.usflib` soundbanks.
- **Coverage** — PSF v0x21 headers and `[TAG]` blocks in USF/miniusf streams,
  plus companion `.usflib` structure.
- **Status** — Profile validated against a real-source UAC fixture and a
  389-package source scan; full collection conversion remains pending.

## Field Mapping

Store the canonical platform once as structural
`game.console = "Nintendo 64"`. On each `.miniusf` / `.usf` member, use
structural **format** `"USF"` with `role = "playable"`. The PSF version byte
`0x21` is surfaced as member **Format** `"USF v.21"`. On companion `.usflib`
members, use structural **format** `"USF Library"` with `role = "asset"`.

| Source Tag | UAC Tag | UAC Coded Tag | Tag Notes |
| --- | --- | --- | --- |
| `game` | Game Title | `game.metadata["Game Title"]` or `members[].metadata["Game Title"]` | Keep the source-authored name per member until every playable member has the same non-empty value; then lift it to package metadata. Do not overwrite canonical No-Intro `Game ID` or structural `game.title`. |
| `title` | Title | `members[].metadata["Title"]` | Title for this USF member. |
| `artist` | Artist / Album Artist | `members[].metadata["Artist"]`, optionally `game.metadata["Album Artist"]` | Preserve member values when they differ or are incomplete. If all playable members agree and no explicit `album artist` tag is present, the value may be promoted to package `Album Artist`. |
| `album artist` | Album Artist | `game.metadata["Album Artist"]` or `members[].metadata["Album Artist"]` | Explicit album-artist values take precedence over the artist fallback; lift only when every playable member agrees. |
| `usfby` / `usf by` / `psfby` / `encodedby` / `encoded by` | Dumper | `members[].metadata["Dumper"]` | Copy the native dumper value to the exact playable member that supplied it. Omit placeholders such as `UNKNOWNFILE`, `unknown`, or `?`; never synthesize package-level `Dumper` from member values. |
| `tagger` / `taggedby` | Tagger | `game.metadata["Tagger"]` or `members[].metadata["Tagger"]` | Lift only when every playable member has the same non-empty value; otherwise retain per-member values. Conflicting aliases remain a review error. |
| `copyright` | Copyright | `game.metadata["Copyright"]` or `members[].metadata["Copyright"]` | Preserve copyright holder (e.g. `Nintendo`, `Rare`). Lift only when every playable member has the same non-empty value. |
| `genre` | Genre | `game.metadata["Genre"]` or `members[].metadata["Genre"]` | Preserve genre string (e.g. `Sports: Snowboarding`). Lift only when every playable member has the same non-empty value. |
| `year` (ISO date `YYYY-MM-DD`) | Date & Year | `game.metadata["Date"]` and `game.metadata["Year"]`, or member equivalents | Map ISO dates to `Date` (`YYYY-MM-DD`) and `Year` (`YYYY`). Promote each field only when all playable members carry the same value. |
| `date` (ISO date `YYYY-MM-DD`) | Date & Year | `game.metadata["Date"]` and `game.metadata["Year"]`, or member equivalents | Map when it agrees with any surfaced `Date` or `Year`. Retain the native lowercase `date` field when values conflict, so the source evidence is not discarded. |
| `year` (4-digit `YYYY`) | Year | `game.metadata["Year"]` or `members[].metadata["Year"]` | Map the four-digit release year; promote only when every playable member carries it. |
| `track` / `tracknumber` | Track Number | `members[].metadata["Track Number"]` | Preserve source track index as integer (when numeric) or string (when alphanumeric, e.g. `15a`). Conflicting aliases are a review error. |
| `_lib` / `lib` / `_usflib` | Companion Library | `members[].metadata["Companion Library"]` | Resolve to the exact in-package `.usflib` member path. Some source tags omit the `.usflib` extension; accept a unique exact stem match. |
| `length` | Play Length (ms) | `members[].metadata["Play Length (ms)"]` | Parse `mm:ss`, `mm:ss.ms`, or seconds string into integer milliseconds. |
| `fade` | Fade Length (ms) | `members[].metadata["Fade Length (ms)"]` | Parse fade duration into integer milliseconds. |
| `comment` | Comment | `members[].metadata["Comment"]` or `game.metadata["Comment"]` | Preserve source comment if populated; omit blanks. |
| PSF header version byte `0x21` | Format | `members[].metadata["Format"]` | Derive from each unchanged playable member header as `USF v.21`; do not write generic `Format=USF` metadata. |

## Format Procedures

- **Dependency soundbank assets** — Companion `.usflib` files are non-playable
  audio state/sample data required by the playback core. They must have
  `role: "asset"` and `format: "USF Library"`. Each `.miniusf` track must record
  its declared dependency via `members[].metadata["Companion Library"]`; the
  referenced path must resolve to exactly one in-package library. Four tracks
  in the scanned 389-package corpus had no `_lib` tag (All Star Tennis 99,
  Asteroids Hyper 64, and two Monopoly source packages); preserve that absence
  rather than inventing a dependency.
- **Character encoding fidelity** — USF `[TAG]` blocks in legacy rips often
  contain Windows-1252 / ISO-8859-1 character sequences (such as `°` in
  `1080° Snowboarding`). The parser must decode UTF-8 first, then cleanly fall
  back to CP1252/ISO-8859-1 rather than injecting Unicode replacement
  characters (`U+FFFD`).
- **Unanimous package promotion** — `Game Title`, `Album Artist`, `Tagger`,
  `Copyright`, `Genre`, `Date`, `Year`, and `Comment` may be promoted only when
  every playable member has that same non-empty value. Missing values count as
  non-unanimous. Remove per-member copies only after a successful promotion.
- **Track-specific value retention** — Keep non-uniform or partially populated
  Game Title, Artist, Tagger, Copyright, Genre, Date, Year, and Comment values
  on their source members. Dumper always remains on its exact source member and
  is never promoted from member tags to package scope.
- **Identity-first title separation** — Structural `game.title` carries the
  canonical game title selected by the reviewed identity workflow. Package
  `Game ID` is the canonical No-Intro title root when positive evidence exists;
  source-authored `game` tags remain separately visible as `Game Title`.
- **Playback timing gate** — Parse source `length` and `fade` strings into
  integer milliseconds (`Play Length (ms)` and `Fade Length (ms)`). Every
  source-timed USF member must carry a positive `Play Length (ms)` integer.
- **Variant and issue labels** — Use reviewed filename qualifiers such as
  `(Demo)`, `(Beta)`, and `(Homebrew)` for distinct productions under the
  AudioMan final-sort procedure. Use `[alt]` on a smaller same-game rip when
  its playable stream-state multiset differs from the larger compared rip;
  keep that alternate in Review. `[alt]` is a filename qualifier, not a UAC
  status or an incompleteness claim. Do not put production or alternate labels
  in UAC `Status`; that field is reserved for `Mixed Versions`, `Incomplete`,
  and `Corrupt` issues defined by the base profile.
- **Region and library names** — A `.usflib` serial such as
  `NUS-NTEA-USA.usflib` is a territory and serial clue, not a ROM revision
  claim. Use it with the full No-Intro candidate set; if all contained library
  serials agree and the matching DAT object corroborates the serial, it can
  support territory. Otherwise keep `Region=--`.
- **Shared multi-market ROMs** — A combined value such as `JP, US` is valid
  only when one exact DAT entry names both markets and contains one ROM object.
  If libraries are present, their serials must agree on one territory within
  the combined set and match the DAT serial. Separate DAT rows or ROM objects
  for Japan and USA must not be combined into one Region value, and a
  shared-market DAT entry must not be narrowed to the territory suffix on its
  library filename. In the current N64 BigEndian snapshot, 1080 Snowboarding
  DAT `0007` is one Japan/USA ROM object with serial `NTEA`; DAT `0006`
  (Europe) and `1136` (USA LodgeNet) are distinct ROM objects. The matching
  `NUS-NTEA-USA.usflib` supports retaining `Region=JP, US` for the DAT `0007`
  source, without claiming that it matches a particular ROM revision beyond
  that DAT entry.
- **Format boundaries** — A USF UAC contains USF/miniusf playable members and
  their `.usflib` assets. Other playable formats such as `.mid` or `.wav` need
  their own reviewed format disposition; they must not be silently mixed into
  the USF payload or discarded from set-level accounting.

## Current Source Scan

The 2026-10-24 audit covered 389 USF packages (243 JoshW, 146 Zophar), 17,372
`.usf`/`.miniusf` members, and 398 `.usflib` assets. All 17,372 playable
members had PSF version byte `0x21`; all declared library references resolved
to one in-package asset, with no broken references. Four playable members have
no library tag and remain explicit gaps.

The all-track package promotion scan found unanimous non-empty values in 372
packages for `Game Title`, 245 for `Artist`, 315 for `Copyright`, 276 for
`Genre`, 317 for `Year`, and 358 for `Dumper` (`usfby`). It also found 31
artist conflicts, seven dumper conflicts, and four genre conflicts. Missing or
conflicting fields stay at member scope; package metadata must not erase them.
These counts describe tag coverage, not identity, completeness, or promotion
eligibility.

## Required Checks

- **USF / miniusf / usflib structure** — Validate the `PSF` signature, USF
  version byte `0x21`, 16-byte header, reserved/compressed sizes, compressed
  payload CRC32, and `[TAG]` boundary computed from the header. Each playable
  member receives its header-derived `Format=USF v.21` tag.
- **Companion library resolution** — Ensure every declared `_lib` `.usflib` file
  resolves to exactly one library member within the package payload.
- **Package integrity** — Run `uacman inspect --verify` to guarantee seekable
  payload checksums and manifest round-tripping.
- **Payload bit-for-bit preservation** — Manifest normalization via
  `normalize_usf_uac_tag_surface.py` must rewrite only the JSON manifest block
  without modifying payload BLAKE3 checksums or stream bytes.
