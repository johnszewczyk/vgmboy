# Sony PlayStation · Disc Audio Profile

Apply the [UAC Base Profile](BASE-UAC-PROFILE.md). This profile covers one
playable source format per UAC: XA streams or Red Book CD-DA tracks. Keep
different playable formats in separate UAC packages. Extraction and
game-specific loop evidence are defined in the
the PSX preservation protocol in the VGMManDocs UACMan library.

## Scope

- **Source members** — One playable source format per UAC: XA or Red Book
  CD-DA. Stored encodings may include `xa`, `ape`, or `flac`.
- **Source authority** — Review source tags, CUE data, release records, and
  measured audio facts; do not infer metadata from filenames.
- **Format boundary** — `.psf`, `.psf2`, `.minipsf`, and related PSF-family
  files are separate MetaMan formats and need their own profiles.
- **Status** — Approved procedure; keep package-specific evidence in dated
  reports.

## Field Mapping

Store the canonical platform once as structural
`game.console = "Sony PlayStation"`.

| Source Tag | UAC Tag | UAC Coded Tag | Tag Notes |
| --- | --- | --- | --- |
| — | Game ID | `game.metadata["Game ID"]` | Add only after one matching release is verified from an authoritative record. |
| — | Region | `game.metadata["Region"]` | Use a source-backed two-letter code such as `US`; use the same code in the package name. |
| — | Set Name | `game.metadata["Set Name"]` | Use the exact source collection name. |
| — | Set URL | `game.metadata["Set URL"]` | Keep source URLs and checksums in `sources[]`. |
| — | Album | `game.metadata["Album"]` | Use an established soundtrack title without a region suffix; do not infer it from a filename. |
| — | Album Artist | `game.metadata["Album Artist"]` | Store a verified shared release artist once at package level. |
| CUE global `PERFORMER` | Album Artist | `game.metadata["Album Artist"]` | Use only when global to the release. |
| CUE track `TITLE` | Title | `members[].metadata["Title"]` | Attach to the audio member; no filename fallback. |
| CUE track `PERFORMER` | Artist | `members[].metadata["Artist"]` | Track credit takes precedence over Album Artist. |
| `Composer` (authoritative per-track source) | Artist | `members[].metadata["Artist"]` | Apply the shared artist rule. |
| — | Publisher | `game.metadata["Publisher"]` | Keep source-backed; do not infer Developer. |
| — | Developer | `game.metadata["Developer"]` | Keep only when separately established by an authoritative source. |
| — | Date | `game.metadata["Date"]` | Use a full source-backed date; capture time belongs in provenance. |
| — | Year | `game.metadata["Year"]` | Use when an authoritative source gives only a year. |
| CUE logical track number | Track Number | `members[].metadata["Track Number"]` | Store soundtrack order; physical CUE indexes stay in the attachment. |
| — | Disc Number | `game.metadata["Disc Number"]` | Use only for a multi-disc release; omit for a single disc. |
| XA stream or Red Book CD-DA | Format | `game.metadata["Format"]` | Use one package-level value; keep XA and Red Book audio in separate UAC packages. |
| — | Play Length (ms) | `members[].metadata["Play Length (ms)"]` | Measured timing used by playback policy and duration readouts. |
| — | — | `members[].metadata.loop` | Keep a source-backed sample-accurate loop only when playback uses it. |

## Format Procedures

- **First-pass eligibility** — This loose-file collection includes all
  source-backed items; do not require a Game ID for initial processing. Keep
  unresolved release identity explicit until a positive match is established.
- **XA and Red Book** — XA is a source stream. Red Book CD-DA is a disc
  source type, not an extension; retain source identity in the provenance or
  transformation record.
- **CUE attachment** — Preserve CUE bytes. They are authoritative for physical
  tracks, indexes, and pregaps; keep BIN checksums in the source record.
- **Source-image storage** — Keep full BIN images and downloaded archives
  outside UAC payloads by default. A UAC is optional when tagged audio and CUE
  are sufficient.
- **Hashes and technical facts** — Retain wrapper integrity hashes without
  duplicate tag checksums or decoded-PCM catalogs. XA reader facts and sector
  mappings are source evidence, not music tags.

## Required Checks

- **Release mapping** — Verify source release, CUE, and member mapping before
  packaging.
- **Tag review** — Distinguish retained, projected, and authored values; leave
  missing titles and credits absent.
- **Package verification** — Run `uacman inspect --verify`; check roles,
  paths, sizes, field coverage, CUE identity, playlist order, and positive
  loop objects.
- **Collection report** — Record counts and unresolved mappings in a dated
  report under `UACMan/ai/reports/`.
