# SB2 / SBO playlist columns

## Current evidence

- Hosted release: MathBook `eb6878b`; canonical presentation source: VGMMan
  `46e7a959`. Both commits are pushed. Deployment used a clean Git archive so
  unrelated working edits were excluded; `private-admin` is active.
- Source checks: changed JavaScript parses, Python compiles, Django system check
  passes, and the SB2/SBO presentation sync check passes. No SB2 test suite was
  added or run.
- API fixture: Year/Dumper survive the public projection, album, detail and search
  responses; source archive/member/path fields remain absent. The fixture uses
  disposable metadata and does not mutate the hosted catalog.
- Live signed-in desktop browser: Street Fighter II: The World Warrior, 45 rows.
  Every visible header and body column had matching position/width and no clipped
  text after reload. Dragging Title changed header/body from 213px to 263px and
  disabled auto-size; double-click restored 213px and auto-size. Header reorder
  moved the matching row cells. Original order was restored and survived reload.
  Empty Artist, Year and Dumper columns stayed hidden; Year/Dumper controls were
  visible in Options. No browser console errors were recorded.

## Limits

The current hosted catalog has no Year/Dumper values; publication must supply
those fields before real hosted rows can display them. Native File/Path columns
remain private to local apps. This pass did not exercise a packaged SB2 window,
phone layout, audio playback, or every hosted catalog album. Shared source checks
are not packaged UI proof.

## Desktop collections and album margin — 2026-10-26

- SBO `0a141d6`: deployed from committed source. Recents rendered 100 events
  across 14 albums in the standard playlist, with cards hidden. Selecting
  1941: Counter Attack showed 3 history events while retaining Recent. Reload
  preserved that album selection. Console counts matched the 14 loaded albums.
- All visible ordinary cells had one computed foreground (`rgb(133,138,167)`).
  Searching Guile locally showed 14 events in one album. No console errors were
  recorded; the search and album scope were cleared after inspection.
- Disposable API fixture passed for metadata/duration, retained missing-track
  snapshots, and omission of archive/member/path fields. Django check and changed
  JavaScript parsing passed. Phone cards/swipe behavior was retained in source;
  no new phone interaction pass or audio test was performed.
- SB2 `73a037ac` plus build-entry fix `48c60292`: the normal build completed,
  signed bundle passed strict verification, and the packaged window launched.
  Console View filtered to Rockman X showed aligned counts and independent star
  buttons. Favorite mutations use the existing FavoriteStore group toggle;
  live user favorites were not changed during this UI check. No test suites ran.
