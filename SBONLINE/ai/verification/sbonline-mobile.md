# Mobile navigation, Favorites, Listening, and shared Options

## Latest evidence — 2026-10-26

- Releases `30b7ad3` and `45ef7f7` move bulk Favorites editing from the player
  into the owner's Profile, consolidate phone search into the persistent header,
  add identity/icon navigation to the 80vw left drawer, and simplify Listening
  into Now playing / Played tabs. The existing queue remains separate.
- Signed-in production at 390×844: Profile Select / All shown selected all seven
  favorites and enabled Remove; Done cleared selection. No live favorites were
  removed. Player Favorites had no edit toolbar. The batch endpoint fixture also
  covered whole-album removal and isolation from another account.
- Header search from Profile opened the Library and returned Dogyuun tracks after
  the existing up-front catalog build. At 320×740, document width equalled 320px;
  menu, transport, search, Queue, and Options stayed within the header.
- The deployed `sb-interface.js?v=20261026-shell-2` cleared the stale Recent
  selection marker when focus entered the header search; only the active view
  retained its selected style.
- The left drawer displayed the member avatar, name, play count, and navigation
  icons. Its Options button closed navigation and opened the existing Options
  drawer. Queue opened independently in its original right-side panel.
- Listening's Now playing / Played tabs switched panels and updated the URL hash;
  Played used compact shared artwork/text cards and day filters. The redesigned
  view is captured in `sbo-listening-unified.png` in this chat's visualization folder.
- At 1200×850, the mobile search was hidden, the desktop explorer remained intact,
  document width equalled 1200px, and exactly one audio element remained.
- Deployment used Git archives of committed source, excluding unrelated working
  edits. Unchanged streaming source retained its prior build timestamps. The
  production service remained active; JavaScript syntax, Django checks, Python
  compilation, temporary database fixtures, and whitespace checks passed.

## Earlier evidence — 2026-10-26

- Releases `8c2c76e`, `ac41f65`, and `22ec996` implement selection removal,
  shared player styling, compact phone layouts, and recoverable removal errors.
  Deployments use committed source, excluding unrelated working edits.
- Disposable SQLite fixtures exercised batch removal, partial album conversion,
  preservation of original favorite timestamps/order, isolation from another
  account, invalid/unknown requests, and rollback after an injected write failure.
  Live user favorites were not changed by verification.
- Signed-in phone UI at 390×844: Select and All shown selected one/all seven
  Favorites; row clicks toggled selection without starting audio. Removal enabled
  only with a selection. No swipe-delete underlays remained in Favorites. Done
  cleared selection. No horizontal page overflow was observed.
- Options at 320×740 and 390×844: Playback/Interface field widths and right edges
  matched, inputs used 16px text, and Audio displayed matching custom sliders.
  The 320px fields were 127.68px wide and ended at x312. Closing Options returned
  focus to its opener. Profile retained the shared monospace theme without overflow.
- At 1200×850 the desktop drawer was 608px wide, anchored to the right edge, with
  four 160px Playback controls aligned at x1192. The document retained one audio
  element. Temporary browser viewport overrides were reset.
- JavaScript syntax, Python compilation, Django checks, and Git whitespace checks
  passed. The usual pre-existing HSTS-preload deployment warning remains.

## Limits

The actual removal request was verified against disposable database fixtures,
not the live user's Favorites. This pass did not exercise audio playback, mobile
hardware Safari, every site route, or assistive technology on a physical phone.

## Pending release: unified menu and Admin

Source checks passed: Django check, JavaScript syntax, and disposable SQLite
fixtures for Admin rendering, valid/invalid settings saves, legacy Profile redirect,
and denial of ordinary-member access. No live settings were changed.
Deployment and rendered UI checks remain pending because the requested rate-limit
reserve was approached. Verify Navigation / Options switching, keyboard focus,
Home navigation, narrow-screen sizing and Admin form layout before release.
