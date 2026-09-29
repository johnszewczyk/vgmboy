# SOTN PSX UAC tag cleanup — 2026-09-29

## Final package

`audio/Derived/Export/PlayStation/Castlevania - Symphony of the Night (US)/UAC/Castlevania - Symphony of the Night (US).uac`

The package exposes direct Title Case fields. At package scope these are
**Game ID**, **Region**, **Set Name**, and **Set URL**. At track scope the
populated fields are **Title**, **Artist** when present, **Album**, **Platform**,
**Format**, **Track Number**, and **Play Length (ms)**. Single-disc
**Disc Number** values were omitted. **Album** is the game/soundtrack title
without region or the former `PSX XA audio` suffix. XA **Title** values retain
the official OST reconciliation; no title was inferred for the Red Book APE
member from its generic `Redbook Audio Track 02` placeholder.

The logical SOTN sequence remains numbered `01`–`39`, starting at `01` as
requested for the soundtrack-oriented set. This sequence is separate from
physical disc numbering: the attached byte-exact CUE records XA data on
physical track 01 and Red Book audio on physical track 02. The package keeps
all 39 playlist targets and their playback order.

No **Year** or **Date** tag is present in the package or the available member
tags. The Redump source's `observedAt` value is a source-capture timestamp, not
a release date, so it was not promoted.

## Loop and source evidence

All 26 sample-accurate `metadata.loop` objects were preserved exactly, including
their half-open sample boundaries, sample rate, infinite repeat, and native
`DRA.BIN XaMusicConfig` provenance. The two unresolved native loop pairs remain
unresolved in the attached certification/report. Duplicate raw loop
coordinates, source-state/track extras, and repeated playlist titles were
removed; the member loop object remains the playback authority. The lowercase
`loop` key is wrapper-defined playback structure, not a free-form tag.
Each playlist entry retains its required empty `extraFields` object for
UACMan schema compatibility; these objects are structural and not visible tags.

The visible `nativeMetadata`, duplicate `tags`, reader `system`, `game`,
`sourceState`, `discFilename`, and per-member `sourceXA` dumps were removed.
Sector mapping, loop research, archive hashes, source BIN checksums, and the
CUE remain in their existing source/provenance/report locations. The generic
Red Book placeholder title remains inside its unchanged APE member but is not
projected as a UAC **Title**.

## Verification

The manifest-only rewrite preserved the compressed payload BLAKE3. The new
package passed `uacman inspect --verify` and a full unpack. All 45 extracted
members, including every XA/APE stream, CUE, and report, compare byte-for-byte
with the prior package. The 26 loop objects and all 39 positive duration
readouts compare exactly with their prior values.
