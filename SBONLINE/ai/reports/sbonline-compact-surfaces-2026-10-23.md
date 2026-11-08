# Compact SBONLINE surfaces and live presence

## Implemented

- Sidebar labels preserve one character of indentation. Invisible desktop leaf chevrons retain their layout slot, while expandable phone albums and console branches keep disclosure arrows. Empty leaves omit arrows. Mobile parent/child favorites reserve the same 40px column.
- Mobile hides workspace-tab management and Stop, keeps saved desktop contexts, and reduces the browse header from 100px plus a 44px tab strip to 76px total (68px reclaimed). The account portrait is 36 by 36 pixels. Queue no longer repeats “Now Playing” and “PLAYING.” Full-screen scrims are excluded from the shared selection indicator.
- track_card.html is now the only card renderer. Shared Listening JSON returns escaped HTML from this same partial; the duplicate JavaScript card builder was removed. Listening, Spotlight and profile/Favorites cards have an artwork-sized body and one member/time/action footer. Desktop artwork is 128px; phone artwork is 96px. Grid cells do not stretch a single card across an otherwise empty desktop row. Optional Spotlight notes expand on demand.
- Profiles use a compact avatar/form arrangement and collapsed bandwidth details. Removed redundant helper panels. Selects reserve 30px for an inset chevron.
- Shared Listening uses a CSRF token owned by the persistent player. The HttpOnly CSRF cookie remains protected; page navigation no longer removes the token required for presence POSTs. A regression check confirms a missing token gets 403 and the persistent token succeeds on Listening.
- Established presence heartbeats use a single atomic UPDATE without rebuilding the catalog. New playback uses an atomic upsert rather than a read-then-write update_or_create transaction. Successful updates immediately refresh Listening; its requests and event listeners are cleaned up on page leave.
- Long Play duration is reflected in playlist rows/cards as well as the playback clock. Normal VGM now applies the stream wrapper's output fade; the bridge itself deliberately does not own fade timing.
- Deployment excludes transient SQLite journal/WAL/SHM files from its permission sweep, fixing an observed disappearing-journal race. Private parent-directory permissions and the service umask continue to protect runtime files.

## Evidence and boundaries

- Eleven Django checks and fourteen player checks passed. Coverage includes real CSRF enforcement on a formless Listening page, canonical card output, and preserving the start time without catalog work on a repeated heartbeat.
- Production native-loop checks passed loop pitch, offset playback, Long Play/normal VGM fades, normal NSF fade, zero fade and MP4 timestamp continuity.
- Actual Shadow Blasters Boss Theme (normal metadata 54.4 seconds) and Round 8: Evil Palace (44.116 seconds) each rendered exactly 180 seconds through the deployed decoder with Long Play enabled and no decoder error. The user-reported general VGM failure was not reproduced on those files. One-shot files without native loop metadata retain their existing replay behavior.
- Live Boss Theme continued past 54 seconds through a selected 75-second Long Play, then advanced to Round Clear. The original 180-second preference was restored.
- Live Listening displayed the playing member and canonical card. An intermittent heartbeat 500 prompted the atomic heartbeat/upsert change; subsequent updates succeeded. The earlier deterministic 403 was caused by the missing page token.
- At a 390px phone viewport, parent and child favorite buttons both ended at x=382. The portrait measured 36 by 36; Stop and the tab strip were hidden. Desktop labels measured x=15.758 and x=23.578, matching the 7.827px one-character indent to pixel rounding, with hidden leaf arrows.
- The desktop profile form measured 700px wide with a 96px avatar, and bandwidth was collapsed. The owner-selected 160 kbps AAC setting was preserved.
- Responsive checks used browser viewports, not a physical phone. Local SB2 source served as the parity reference; no native SB2 code was changed. All unrelated work was preserved.
