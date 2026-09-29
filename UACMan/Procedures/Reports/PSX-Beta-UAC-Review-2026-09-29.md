# PSX beta UAC review — pass 1 — 2026-09-29

## Scope and verification

Reviewed the current manifests at:

- `Derived/Export/PlayStation/Darkstalkers - The Night Warriors (US)/UAC/Darkstalkers - The Night Warriors (US).uac`
- `Derived/Export/PlayStation/Castlevania - Symphony of the Night (US)/UAC/Castlevania - Symphony of the Night (US).uac`

Read manifest metadata and ran `uacman inspect --verify` at both paths.
Payload verification passed for both packages. This pass did not extract or
rewrite either archive, open source audio members, or verify source-file bytes
against external copies.

| Package | Members | Playable | Decoded manifest | Stored payload | `game.console` | Payload BLAKE3 |
| --- | ---: | ---: | ---: | ---: | --- | --- |
| Darkstalkers | 48 | 45 | 126,388 B | 262,533,953 B | `PSX` | `db15eaeb7fd1ad8434a171dc27774f608c237f4c87a7abec42738508a8c8262c` |
| Castlevania: Symphony of the Night | 45 | 39 | 106,777 B | 259,423,060 B | `Sony PlayStation` | `ab00de485fff619c3ce27ff55a8dfa32ebb8810505ed145ba865a98d7b466910` |

## Current tag surfaces

### Darkstalkers

- Package tags: **Game ID**, **Region**, **Set Name**, **Set URL**.
- All 45 playable members have **Album**, **Format**, **Platform**, and
  **Track Number**. The values are uniform for Album, Format, and Platform;
  Track Number covers physical CUE tracks `02`–`46`.
- **Platform** is redundant with package system identity. `game.console` is
  currently `PSX`; the canonical value is `Sony PlayStation`.
- No **Disc Number**, **Set Collection**, **Title**, or credit tag is present.
  The absence of track titles and credits matches the source review; do not
  invent them.
- The CUE and Redump verification table are included as assets. Playlist order
  is 1–45 while Track Number records physical tracks 02–46; these meanings are
  distinct and documented.

The 2026-09-29 [track-number repair report](PSX-Darkstalkers-Track-Number-Repair-2026-09-29.md)
matches the current physical numbering and omitted single-disc number. The
2026-09-28 [tag preview](PSX-Darkstalkers-Tag-Preview-2026-09-28.md) is
superseded: its one-based `1`–`45` numbers, **Disc Number** `1`, and
**Set Collection** claims do not describe the current manifest.

### Castlevania: Symphony of the Night

- Package tags: **Game ID**, **Region**, **Set Name**, **Set URL**.
- There are 39 playable members: 38 XA and one Red Book track. All have
  **Album**, **Artist**, **Date**, **Format**, **Platform**, **Play Length
  (ms)**, **Title**, **Track Number**, and **Year**. **Format** has two values;
  **Artist** has 37 `Michiru Yamane`, one `Cynthia Harrell`, and one
  `Konami Kukeiha Club` value.
- **Platform** `PSX` duplicates the canonical package value in
  `game.console` (`Sony PlayStation`). Remove the member field in a later
  manifest-only cleanup.
- **Date** is `1997-10-02` on every track and **Year** is `1997` on every
  track. Under the shared base rule, retain **Date** and omit the redundant
  **Year** field in a later cleanup.
- **Play Length (ms)** is present on all 39 members and is consumed as a
  duration readout. Keep it only while that display remains useful.
- The continuous soundtrack sequence is `01`–`39`; all 26 positive native loop
  objects remain playback structure and should be retained. The CUE continues
  to carry physical disc numbering.

The existing [SOTN cleanup report](PSX-SOTN-Metadata-Cleanup-2026-09-29.md)
records the applied title/order/date/loop edits. This pass identifies only the
remaining system alias and redundant Year field for a follow-up review.

## Wrapper fields are not extra music tags

Both packages contain the wrapper's standard four scoped
`uac-playable-payload-v1` hash records per playable member. The UAC packer
creates these records; `uacman inspect --verify` checks supported records.
They belong to wrapper integrity metadata, not the ordinary tag surface.
Keep them. The earlier PSX wording against a “second playable-payload hash
list” must not be read as a request to delete the wrapper records or create a
custom checksum export.

Likewise, package identity/provenance is split across the manifest by role:
`game.metadata` holds direct user-facing tags, `game.console` holds canonical
system identity, and `sources[]` records source provenance. These are not
separate tag stores. Review any same-value copy across those locations against
the user-facing need before creating it.

## Profile revision

The shared [UAC Base Profile](../BASE-UAC-PROFILE.md) now holds the rules for
direct fields, Title Case, omissions, date precision, system identity, and
wrapper structures. The format template and PSX profile now keep only their
mechanical mapping and PSX-specific exceptions. The Profiles Beta page includes
the shared base profile.

No package manifest or source member was changed in this pass. Proposed next
edits are limited to removing the two **Platform** aliases, canonicalizing
Darkstalkers `game.console`, and removing SOTN **Year** while retaining its
full **Date**. Keep SOTN durations and loops only while their documented
consumers require them.
