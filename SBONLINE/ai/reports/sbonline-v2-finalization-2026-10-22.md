# SBONLINE revision 2: AAC and player parity

Owner: MathBook/private-admin. Source packages and native decoder libraries were not modified.

## Changes

- AAC-LC in fragmented MP4 is the only audio output. Removed MP3 encoder/fallback code, obsolete codec preference, owner trial context processor, and their settings columns (migration 0031).
- Profile → Site settings exposes one superuser-only global AAC bitrate: 96/128/160/192/256 kbps. Existing 192 kbps is preserved. New streams read the setting once; current playback is unaffected.
- Fade Out applies to every source format, matching the local playback preference. Demitri's source metadata has zero fade; previously online incorrectly inherited it for non-SPC Long Play. Finite Long Play includes the user fade; unlimited has none. The current clock uses the generated duration returned by the server. The normal libgme path now also uses our output envelope, removing its fixed fade duration.
- An interrupted AAC stream resumes at its absolute position when Play is pressed, including premature EOF. Normal pause resumes the same buffered resource. Unsupported browsers get an explicit error; no alternate codec request occurs.
- Desktop Favorites renders one numbered playlist. Playing a favorite queues Favorites rather than its album. The normal library sidebar stays available, and selecting an album returns to Library. Removed obsolete per-album Favorites selection state.
- Dedicated sb-mobile.css supplies labeled library views, touch-sized controls, and a bottom transport dock. It reuses the desktop engine, queue, theme and motion. Desktop density is unchanged.
- Removed CSS hiding the player on other authenticated desktop pages; shared navigation keeps the existing engine. Playback actions from those pages are accepted consistently.

## Dead-page audit

All remaining accounts page templates are referenced. Retired chat/feed/community/password-change URLs already redirect, and are retained for bookmarks. Active Listening, Spotlight, member profiles and member Favorites remain. No member content was deleted. Historical migrations retain their original schema definitions; migration 0031 removes the obsolete current settings.

## Validation

- 14 player regression checks passed, including absolute AAC interruption recovery, ordinary pause without source replacement, unsupported AAC, reload/login reconstruction, and correct terminal advancement.
- 10 Django bitrate authorization/validation, atomic quota and Long Play timing checks passed. Migration dry run reports no drift.
- On the production decoder, the synthetic intro/loop fixture passed pitch continuity across repeated seams, offset playback, linear VGM fade RMS checks (including resume within the fade), normal NSF configurable and zero-fade checks, and contiguous MP4 packet timestamps.
- Live owner profile displays only Global AAC bitrate and preserves 192 kbps.
- Live phone-sized browser inspection confirmed labeled browse controls and the bottom playback dock. This is responsive browser verification, not a physical iOS device test.

- Live Demitri AAC Long Play passed 3:35, reached its four-minute ending, and advanced to DEMITRI Winning without a restart. Buffered media stayed about 30 seconds ahead and older media was evicted.
- Final live desktop check: Favorites retained its selected view, showed six flat tracks, kept all 2,235 library albums available, and queued six Favorites rather than the 48-track Demitri album.
- Final live navigation check: moving from SPCBOY to Profile kept the same blob audio resource playing and retained a visible dock. Full Profile reload restored 0:31; browser autoplay protection required Play, after which the absolute clock advanced to 0:40. No live logout was performed; login reconstruction remains covered by the regression checks and earlier recorded live verification.
- Verification caught a stream cut by deployment's second service restart; after deployment finished, Play resumed from the absolute interruption position. Service restarts can still interrupt active HTTP streams; recovery is explicit and does not silently restart the song.
- Restored the original three-minute Long Play preference and stopped test audio. Saved responsive proof: /tmp/sbonline-mobile-v2.png (Demitri beyond 3:35). Native-loop check ran against the deployed wrapper after rebuilding it serially.
