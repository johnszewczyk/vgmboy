# PSX Redump Metadata Cleanup — 2026-09-26

## Status

Two corrected UAC candidates were built and verified in `/private/tmp/psx-final-packages/`.
The live package replacements and `audio/Derived` reorganization were not
applied: the desktop automatic review rejected the combined filesystem write.
The current Derived tree is unchanged. The exact field-removal ledger is
`PSX-Redump-Metadata-Cleanup-2026-09-26.jsonl`.

## MetaMan findings and proposed UAC surface

### Darkstalkers: The Night Warriors (USA)

- The 45 Red Book tracks have no native loop metadata. The corrected candidate
  contains no `LOOP_TYPE=none`, `LOOP_PROVENANCE`, `loopStatus`, or loop object.
- MetaMan's source APE tags are retained as native source evidence. The
  user-facing track metadata keeps the populated music fields; repeated region,
  CUE, and system facts are represented by package/source structure where
  available instead of copied onto every track.
- All 45 playable members have BLAKE3-256, CRC32, SHA-1, and MD5 stream hashes.
- The candidate contains 51 members and passed `uacman inspect --verify` with
  payload verification. Its payload BLAKE3 is
  `0c211e075f69bf1993e9f825f3ee00cde3b73dc5e1d60a604de63ed95b3b9173`.

### Castlevania: Symphony of the Night (USA)

- MetaMan scanned all 38 XA members with no diagnostics or failures. Each
  measured header reports 4-bit, stereo, 37,800 Hz audio. The candidate keeps
  the complete structured MetaMan technical facts and does not promote
  duplicate `XA_*` tags or MetaMan's synthetic `comment: Sony XA header`.
- The 26 positive, source-backed loop maps remain. Members without a verified
  loop have no loop field or negative loop tag.
- Each of the 39 playable members has BLAKE3-256, CRC32, SHA-1, and MD5 stream
  hashes. The package-level source archive record retains its four known
  hashes; no source archive was rehashed for this cleanup.
- The candidate contains 45 members and passed `uacman inspect --verify` with
  payload verification. Its payload BLAKE3 is
  `ab00de485fff619c3ce27ff55a8dfa32ebb8810505ed145ba865a98d7b466910`.

The format rules are in [`../PSX-CDXA.md`](../PSX-CDXA.md) and
[`../../protocols/PSX-CDXA.protocol.md`](../../protocols/PSX-CDXA.protocol.md).
The per-field before/after values are in the JSONL ledger so removals are
auditable rather than inferred from the final packages.

## Derived cleanup plan

Group retained project directories under `Derived/PlayStation/`, `Derived/Saturn/`,
`Derived/3DO/`, `Derived/N64/`, `Derived/PC/`, `Derived/Sega CD/`, and
`Derived/Operations/`. Keep source archives, raw extractions, and active
workshops in those study folders. Put completed outputs under the matching
`Derived/Export/<console>/` directory. The planned moves are listed below; none
has been applied.

| New folder | Project directories to move from the Derived root |
| --- | --- |
| `PlayStation/` | `Bio FREAKS (PSX)`; `Bloody Roar (USA) [XA loop study]`; `D (USA, Europe) [Redump source]`; `D (USA) [PSX audio workshop]`; `D (USA) [PSX Redump source]`; `Darkstalkers - The Night Warriors (USA) [Redump audio harvest]`; `RE2PLAY`; `Redump-PSX-Castlevania-SOTN-20260919` |
| `Saturn/` | `D (Saturn) [Redump source]`; `King of Fighters (Saturn) [Redump source]`; `Resident Evil (Saturn) [Redump source]` |
| `3DO/` | `Doctor Hauzer (Japan) [audio harvest]`; `NeuroDancer - Journey into the Neuronet! (USA) [audio harvest]` |
| `N64/` | `1080 Snowboarding (Japan, USA) [N64 audio workshop]`; `Resident Evil 2 (N64) [AudioHarvest]`; `Rips - N64` |
| `PC/` | `Resident Evil 2 (1998) [PC audio harvest]`; `Resident Evil 2 (1998) [PC source]` |
| `Sega CD/` | `Eternal Champions - Challenge from the Dark Side` |
| `Operations/` | `AudioMan`; `UAC beta repack 2026-09-17`; `VGM 1.71 Freshening 2026-09-17` |

- Install the verified SOTN candidate at
  `Export/PlayStation/Castlevania - Symphony of the Night (US)/UAC/`; remove
  the old source-study UAC and its two package snapshots, then move the
  remaining source study under `PlayStation/`.
- Replace the existing Darkstalkers export UAC with the verified candidate.
- Move the completed Top Gear Rally XM recovery under `Export/N64/`.
- Move the existing NeuroDancer deliverables under `Export/3DO/`.
- Remove only these previously confirmed archive/unpacked duplicates:
  `Export/3DO/3DO (Flac)/NeuroDancer - Journey into the Neuronet! (US).tar.zst`,
  the NeuroDancer corrected-HEVC `.tar.zst`, and the Eternal Champions FLAC
  `.tar.zst`.
- Remove the eight NeuroDancer `.ape` trial encodes from its export package;
  the project notes say this rejected APE trial was superseded by the FLAC set.

The eight files are `01-credits.ape`, `02-intro.ape`, `03-jendance.ape`,
`04-jentfui.ape`, `05-katdance.ape`, `06-kattfui.ape`, `07-kimdance.ape`, and
`08-kimtfui.ape` in
`Export/3DO/NeuroDancer/NeuroDancer - Journey into the Neuronet! (USA) [3DO package]/`.

These removals and moves are pending because the automatic review rejected the
combined write. Unique source archives and unique legacy packages are not part
of the removal list.

The three SOTN files slated for removal from the old study `UAC/` directory
are `Castlevania - Symphony of the Night (US).uac`,
`Castlevania - Symphony of the Night (US).uac.pre-flat-set.bak`, and
`Castlevania - Symphony of the Night (US).uac.pre-tag-cleanup-2026-09-22.bak`.
