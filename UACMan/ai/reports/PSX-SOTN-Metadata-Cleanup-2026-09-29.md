# SOTN PSX UAC metadata and soundtrack sequence — 2026-09-29

## Final package

`audio/Derived/Export/PlayStation/Castlevania - Symphony of the Night (US)/UAC/Castlevania - Symphony of the Night (US).uac`

The package exposes direct Title Case fields. At package scope these are
**Game ID**, **Region**, **Set Name**, and **Set URL**. At track scope the
populated fields include **Title**, **Artist** when sourced, **Album**,
**Platform**, **Format**, **Track Number**, **Play Length (ms)**, **Year**, and
**Date**. Single-disc **Disc Number** values are omitted. **Album** identifies
the game, without region or the former `PSX XA audio` suffix.

The 34 XA music members now follow the English soundtrack sequence at `01`–`34`.
Their existing **Title** values already match the corresponding 34-track
English rendering of the official soundtrack, so the update changed sequence
numbers, not those 34 titles. The 5 game-disc extras follow at `35`–`39`: US
Konami logo, three movie cues in 1/2/3 order, and the Red Book remix. The last
member now has **Title** `Dracula's Castle Remix` and **Artist**
`Konami Kukeiha Club`, sourced from the matching US JoshW playlist entry. The
UAC playlist is ordered the same way. Here **Track Number** is the continuous
logical UAC sequence, including the Red Book bonus at `39`; the attached
byte-exact CUE remains the physical-disc authority: XA is in track 01 and Red
Book audio is track 02. The package member list uses the same logical order,
so UACMan's default Tracks view presents the 34 OST tracks first and the five
extras afterward.

All 39 playable members now have **Year** `1997` and **Date** `1997-10-02`, the
official US game release date. This matches the package's **Album** meaning
(the game title) and its US Redump source. The soundtrack CD itself, King
Records KICA-7760, was released `1997-04-09`; that is recorded here as the OST
release date, not substituted for the US game's release date on this game-disc
package. The source `observedAt` value remains a capture timestamp and was not
used as release metadata.

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
CUE remain in their existing source/provenance/report locations. No physical
audio member was renamed or rewritten.

JoshW's `!tags.m3u` maps soundtrack track 33 to the same `XA_STR1-0437_3c03.xa`
used for track 30. The current UAC already identified that member as
**Metamorphosis 2** and `XA_STR1-0455_4603.xa` as **Metamorphosis 3**; their
durations also align with the listed 0:38 and 0:48 tracks. The UAC mapping is
retained, and the M3U's duplicate path is documented as a playlist mapping
error. Duration was a cross-check, not the sole title source.

## Verification

The manifest-only rewrite preserved payload BLAKE3
`ab00de485fff619c3ce27ff55a8dfa32ebb8810505ed145ba865a98d7b466910`; the
rewriter checked the copied payload while creating the candidate. Readback
confirmed 39 unique track numbers, 34 OST titles in sequence, the 5 appended
extras, `Year`/`Date` on every playable member, and all 26 existing loop
objects unchanged. The existing package-level and member hash records were
retained; the XA and APE members were not rehashed in this follow-up.
Reopening the saved package in UACMan confirmed the first row is **Metamorphosis
1** at Track Number `01`, the OST run ends at **I Am the Wind** at `34`, and
the five extras follow through the Red Book remix at `39`; the GUI showed
**Year** and **Date** on track rows. No GUI edits were saved.

## References

- [King Records KICA-7760 release page](https://www.kingrecords.co.jp/cs/g/gKICA-7760/): official soundtrack release date, 1997-04-09.
- [Konami SOTN history](https://www.konami.com/games/castlevania/us/en-us/page/history_1997_ps): US game release date, 1997-10-02.
- [MusicBrainz English Sound Test rendering](https://musicbrainz.org/release/c3c27d0f-73df-4aec-a6b4-cd332e063648): the 34-track English translation/transliteration used to check the OST title order.
- `JoshW/Sony PlayStation (Inc)/Castlevania - Symphony of the Night.tar.zst`, `!tags.m3u`: cross-check for bonus entries and the Red Book remix credit.
