# Private Admin Service

## Scope

Private account management and usage reporting for `admin.pre-calc.com`.

## Ownership

- `SBONLINE/server/` owns the Django application and account enrollment policy.
- `SBONLINE/ops/server/sbonline-setup.sh` installs the app and vnStat on the existing droplet.
- `SBONLINE/ops/server/private-admin.service` runs Gunicorn as the unprivileged `precalc-admin` account on loopback only.
- `SBONLINE/ops/server/sbonline.nginx.conf` owns the admin hostname's HTTP challenge and final TLS proxy configuration.

## Agent Entry Point

- Start with the private-admin source in this repository: `SBONLINE/server/` and its related `SBONLINE/ops/server/` files. The SSH connection is for server operations and inspection, not editing the deployed tree.
- Read `ai/delivery-ops.md` for the SSH host/account, key requirements, local source-editing workflow, and live deployment command.
- A web account at `admin.pre-calc.com` is not an SSH account. The deployed app at `/opt/precalc-admin/app` is root-owned and replaced by deployment; make changes here in the repository instead.

## Viewport Navigation

- Authenticated desktop site links are rendered once by `accounts/partials/desktop_site_navigation.html`, included from `base.html`. Keep the same text links and route state on every authenticated page; the current route is accented without an underline, and the shared selection surface animates between links. Profile and site stats live in the shared Navigation/Options drawer above its tabs; keep the 64px avatar and total-play/online stat treatment there.
- `site-navigation.js` preserves the player while swapping authenticated page content at every viewport width. `sb-mobile.css` remains linked only at `max-width: 780px`. Keep Favorites/Recent as explicit player-view actions and update route state after same-shell navigation.
- `sb-mobile.css` is the SBO-owned mobile fork layer. Reuse the local SB2-derived `--chrome-bg`, button-surface, and `--sb-radius` tokens for chrome; keep list rows transparent and retain existing page organization. Do not modify or synchronize family-shared components for SBO styling work.

## BOM V4 Sub-site

- `/bom/` redirects to the canonical V4 Reader. It is available only to the owner account and is linked from the Profile tab; the signed-in site landing page remains SPCBOY. The link uses full-document navigation because the shared player shell only swaps among player pages.
- `SBONLINE/ops/server/build_bom_site.py` stages the V4 pages and their explicit runtime data set from the sibling `BOM/` checkout. It also uses BOM's `WKWebView/build_notes_bundle.py` and `notes-embedded-api.js` to package Notes as a read-only snapshot. Pandoc is required for every private-admin deployment.
- The deploy script includes the staged files under `SBONLINE/server/bom_site/`; production serves them through owner-guarded Django views, never `STATIC_ROOT` or a public Nginx alias. Keep the serving views owner-only and `private, no-store`.
- Set `BOM_REPO_ROOT` when the canonical BOM checkout is not at `../BOM`. Do not commit a second copy of BOM's generated corpus into VGMMan. The package records the source BOM commit in `build-info.json`.

## Invariants

- Private admin is a separate app and Nginx virtual host on the current droplet; it is not deployed into the public static document root.
- The app must bind only to `127.0.0.1:8765`; public access is through Nginx and HTTPS.
- Do not issue the first administrator invite until the admin DNS record resolves and the HTTPS certificate and virtual host are active.
- Bootstrap administrator privilege only through the local management command. The Accounts UI may create member invitations but cannot promote members; passkey recovery remains a guarded backend operation and has no frontend control.
- All account-management operations, account directory, sign-in Log, private per-account Usage totals, and droplet telemetry are owner/superuser-only in view guards. Passkey settings remain available to the signed-in account. The old Server route redirects to owner-only Usage.
- Keep invitation creation and cancellation in the Accounts page as the only account-management actions exposed there. Use compact profile cards and one shared button treatment; do not add frontend controls for account deletion, suspension, or passkey recovery. Those operations remain guarded backend mechanisms for managed administration. Cancellation redirects only to the fixed Accounts destination.
- Permanent deletion of a member account is owner/superuser-only, requires a GET confirmation page followed by a CSRF-protected POST, and must never target staff or superuser accounts. Deletion ends all of that member's active Django sessions, closes matching open successful-login events, cancels their unexpired invitations, removes that account's playback history through the user foreign key, and retains username-snapshot sign-in events.
- New member joins require an owner-created one-time invite code entered at `/join/`; there is no open-join mode. The URL carries a random invitation selector, while the owner shares an 8-character unambiguous alphanumeric secret; persist its verification digest and a Fernet-encrypted copy in the invitation row, using a key derived from Django SECRET_KEY. Decrypt codes only while rendering the owner-only Accounts page, mark that response no-store, and never write plaintext to logs. Temporarily carry the raw code in the owner-authenticated session for ten minutes and consume it on the one-time result page. Rows created before encrypted display have a blank ciphertext; without an out-of-band recovered code, the secret cannot be redisplayed. Keep those invitations valid and allow cancellation/replacement. The owner may attach a recovered legacy code with `manage.py restore_invitation_code`, which reads stdin, requires exactly one matching SHA-256 digest, and saves only a Fernet-encrypted copy. Verify codes on an explicit POST before creating a pending account, then require passkey registration before sign-in. Invite codes expire after 24 hours and work once. Limit failures for a known invitation to five; also track invite failures by an HMAC of the client IP, then pause that connection for 24 hours after five failures within 15 minutes. Successful member claim clears that IP throttle. The owner can cancel an open code and create a replacement. Assign internal account names automatically and do not prompt invitees to set one; editable public display names live in Profile. Keep pending passkey setup session-bound for one hour after claim. On upgrade to the code-only flow, revoke any still-open non-recovery invitations created by earlier join flows.
- WebAuthn credentials store only credential IDs, public keys, counters, transports, and a random per-account user handle. Registration requires resident credentials and local user verification; authentication verifies the session-bound challenge, HTTPS origin, relying-party ID, user handle, signature, and authenticator counter. Registration challenges expire after two minutes and are consumed once. Signed-in users manage passkeys from Profile > Sign-in; `/passkeys/` redirects there. Members cannot remove their last credential.
- The root route is the passkey portal for anonymous users and redirects authenticated users to SPCBOY. The login verifier and framework login redirect default to SPCBOY while preserving a validated protected-page `next` URL.
- Sign-in accepts either a discoverable passkey or the account's optional site-generated login password, without asking for a username. Invitation claim still requires passkey registration before first sign-in; a member may then create the password from Profile for use on older devices. Generate 32 random bytes with `secrets.token_urlsafe`, show the result once on a no-store response, and persist only an HMAC-SHA256 digest keyed by Django `SECRET_KEY`. There is one active generated password per account; replacement invalidates the prior digest and revocation deletes it. Never put a password in a URL or log entry. Password attempts share the existing HMAC-IP throttle: five failures in 15 minutes pause the connection for 24 hours. Failed attempts use a generic response and an audit row without the supplied secret. Existing Django password hashes remain unusable. Assign a random internal Django username when an invite is claimed. Do not prompt members to choose a login name; `PasskeyAccount.username_set` remains only for migration/backward compatibility. The public display name is a separate editable `MemberProfile` field.
- New account setup and backend-managed recovery both require a passkey registration before sign-in. Recovery invitations keep a random one-use code digest and Fernet-encrypted copy, a 24-hour expiry, and a five-attempt cap; recovery retires existing credentials only when the replacement passkey is successfully stored. Members cannot remove their last passkey. Do not expose recovery controls in the Accounts UI; preserve the owner guard on recovery routes. Legacy member invitation codes recovered out of band may be attached with `manage.py restore_invitation_code`, which reads one code from stdin, requires a unique SHA-256 digest match, and stores only the Fernet-encrypted value. Never include the code in command arguments, output, or logs.
- `MemberProfile` stores one profile per user, a unique case-insensitive public display name, and one optional cropped avatar upload. Without an upload, the avatar uses the first letter of the display name. `is_site_persona` allows an explicitly seeded, non-authenticating site persona to have a read-only public profile without a passkey; it is never editable from member forms, and persona accounts must have unusable passwords and no fabricated WebAuthn credentials. The private Profile page has Profile, Favorites, Recents, and Sign-in tabs; its `tab` query parameter preserves the selected section across reloads. The Sign-in tab manages passkeys and generated login passwords. Public profiles have Favorites and Recents tabs. The profile upload remains a named multipart input without JavaScript; browser crop selection is optional, and the server validates, square-crops, and re-encodes all uploads. The generic text/image Feed and posting endpoints are retired; legacy `CommunityPost` rows and private media remain stored but are not exposed by the site. Keep existing schema and media cleanup hooks until a separately authorized data-retention change.
- Recovery and older invitation codes are not WebAuthn passkeys. Keep the UI terminology distinct.
- Keep the Django signing key and database outside the source tree with owner-only or group-limited permissions.
- A root-only `private-admin-backup.timer` creates daily archives under `/var/backups/precalc-admin`, retaining the 3 newest successful runs. Each archive contains a SQLite online backup, profile/community images, SPCBOY catalog snapshots and gallery thumbnails, and `/etc/precalc-admin.env`; compressed game packages and temporary playback/import payloads are excluded. The archive directory is mode `0700`, and archives are mode `0600`. The status projection at `/var/lib/precalc-admin/backup-status/status.json` is root-owned, group-readable by `precalc-admin`, and exposed only on the owner Usage page. The job has no network access and is constrained to its archive and status write paths. App deployment does not force another backup while a successful archive exists; the daily timer owns routine snapshots. The October 11, 2026 archive is mirrored on the FileVault-protected Mac under `~/Library/Application Support/PreCalc Admin Backups/` with owner-only permissions. Keep the local mirror protected because it includes `/etc/precalc-admin.env`. The droplet archives alone are not disaster recovery for loss of the droplet; do not present them as offsite protection or add a web restore action.
- vnStat on `eth0` is the source for droplet monthly inbound and outbound bytes; history starts when the daemon is installed.
- The Log records successful and failed sign-in attempts that reach Django from its release onward. It stores the Nginx-provided client IP, a bounded user-agent string, timestamp, and login username; authentication secrets are never stored. When a matching account still exists, the Log displays that account's current public profile name; unmatched attempts retain the submitted username. Successful session keys are stored only as SHA-256 digests.
- Only the owner can read the account directory, active browser sessions, login IP/browser details, sign-in events, and per-account Usage. Signed-in members can read shared SPCBOY playback history. Plays are recorded when AAC output begins, have no age-based purge, and begin at the history feature release; account deletion cascades to that account's plays. `/history/` is the Listening page: a live Now Playing section and paginated shared Played history. The owner Log contains active sessions and sign-in events. The expanded session identifier is the existing SHA-256 session-key digest, never the reusable Django session key. Account-management actions, server metrics, and permanent deletion remain owner-only.
- `MemberActivityReadState` retains dormant legacy Chat and Feed cursor fields; active per-account badge cursors cover shared Played history only. `/activity/badges.json` returns authenticated, private no-store counts after those cursors, excluding the current account's own activity and inactive authors. Opening `/history/` advances the Played cursor. The first state creation snapshots the active Played maximum to avoid presenting historical rows as unread. Spotlight and its badge cursor were removed by migration 0035; `/spotlight/` redirects to SPCBOY. Navigation badges refresh every 20 seconds and after in-app navigation.
- Signed-in members can use Profile and site-level Listening. The retired shared People’s Favorites page redirects `/favorites/` to the signed-in member’s `/profile/?tab=favorites`; individual member profiles continue to show their Favorites. The owner can also access the Log for sign-in and active-session activity. The public Users directory is retired; `/community/` redirects to `/history/`, and `/spotlight/` redirects to `/spcboy/`. The live `/history/now-playing.json` API returns only current listeners' track cards plus an online-member count; it does not return offline accounts, per-member last-played snapshots, favorite/play totals, or last-seen details. Count online sessions only for active passkey accounts with an open successful login event and a `last_seen_at` within five minutes. Spotlight pages, posts, votes, badges, models, and tables were removed; migration 0035 drops their stored posts and votes. Public `/members/<user_id>/` profiles remain available to signed-in members; `/profile/` has Profile, Favorites, Recents, and Sign-in tabs, while public profiles have Favorites and Recents tabs. Track activity may link to the relevant public profile. Do not expose IP addresses or browser fingerprints there; those belong in the private Log. Favorites are account-scoped server records synced by `/spcboy/favorites.json` and filtered against the current catalog before writing. SPCBOY’s Recent view is scoped to the signed-in account.

- `SPCBOYNowPlaying` stores at most one current track per member. The player updates it on audio playback and every 20 seconds, and clears it on pause or page exit. `/history/now-playing.json` returns only current track records with profile/display metadata plus an online-member count; online count is based on active passkey accounts whose open successful login event has `last_seen_at` within five minutes. Never use this endpoint to enumerate inactive accounts or return their last-seen and last-played data. The player’s `/spcboy/now-playing.json` endpoint accepts only a signed-in user’s status and catalog track ID.
- `/spcboy/recents.json` returns only the signed-in account’s paginated playback records. `/history/` renders shared site history. The owner Log retains sign-in events and active sessions; keep it independent from the retired Feed.
- Django browser sessions have a rolling 24-hour expiry (`SESSION_COOKIE_AGE = 86_400`, `SESSION_SAVE_EVERY_REQUEST = True`); each authenticated request refreshes the expiry. Active sessions come from unexpired Django database sessions whose account is active and whose session-auth hash still matches. Audit history is retained in the private database; sessions predating sign-in logging remain visible but have no recoverable sign-in IP, browser, or time.
- The displayed device count is the number of active Django browser sessions, not a hardware fingerprint. A browser profile/session is the finest identity available; the expanded fingerprint is a non-reusable identifier for that active session.
- `MonthlyUsage` stores one row per account and UTC month, with authenticated Django response-body byte totals split between normal private pages and `/audio/` or `/media/` routes. The Usage page total is `site_bytes + media_bytes`; its separate `audio_bytes` counter enforces a strict 10,000,000,000-byte AAC streaming allowance per account and UTC month and must not be added again to response totals. Claim each outgoing AAC chunk with an atomic compare-and-update before yielding it; truncate the last chunk to the remaining quota and stop the encoder when exhausted. Migration 0019 seeds this counter from previously tracked `media_bytes` so current-month usage is carried forward. `/spcboy/stream-quota.json` exposes the signed-in account's current usage for player error messaging. `PrivateUsageMiddleware` counts regular and streaming responses on `admin.pre-calc.com`; it stores no request path, IP, or per-request history. Private and public member profiles may render these rows and their tracked totals. Public `pre-calc.com` requests and Nginx-served `/static/` assets are excluded. Counts are measured before Nginx transport, omit headers/TLS overhead, begin at the middleware release, and are not a billing meter.
- `spcboy_audio` encodes AAC-LC as ADTS at the global `SiteSettings.aac_bitrate` (192 kbps default). Only the superuser can change bitrate and the site-wide playback session limit in Profile → Site settings. Session limits are configured as whole minutes from 1 through 1,440, default 120. Account delivered AAC bytes atomically against the monthly quota.
- Run Gunicorn with one `gthread` worker and four request threads on the 512 MiB droplet. Long `StreamingHttpResponse` audio requests must not occupy synchronous workers, whose heartbeat timeout would terminate an active stream after 30 seconds. Keeping one Django worker resident reduces memory pressure while its threads serve the player and other pages concurrently. Keep the worker timeout at 60 seconds as a guard for an unresponsive worker. The player page-load token carries its session limit; browser and stream handler enforce the same deadline, and SPA navigation must not reset it. Legacy tokens without the field retain the prior 60-minute limit.
- Future audio delivery must use Django `StreamingHttpResponse` on `/audio/` or `/media/` to use this rollup. If Nginx or a CDN serves media directly, add authenticated edge-side accounting before switching delivery; Django middleware cannot see those response bytes.
- SPCBOY's authenticated hosted catalog is `/spcboy/catalog.json`; each track points to one member in a compressed ZIP, 7z, or UAC package. Current console groups and game/track counts are: Arcade (Capcom) (99 / 2,999), Arcade (Konami) (97 / 1,861), Arcade (Mixed) (467 / 6,894), Arcade (Namco) (96 / 1,991), Arcade (SegaSys) (118 / 1,455), Arcade (Taito) (116 / 1,567), Atari 5200 (2 / 5), Atari 7800 (1 / 10), Atari Lynx (4 / 28), Intellivision (1 / 2), NEC TurboGrafx-16 (243 / 4,205), Neo Geo Pocket (3 / 45), Neo Geo Pocket Color (17 / 380), Nintendo Famicom Disk System (1 / 1), Nintendo Game Boy (256 / 3,937), Nintendo NES (531 / 7,024), Nintendo SNES (1,414 / 32,990), Sega CD (18 / 425), Sega Genesis (19 / 510), Sega Pico (33 / 569), Sega SG-1000 (3 / 12), Vectrex (15 / 21), Virtual Boy (18 / 400), WonderSwan (5 / 67), and WonderSwan Color (6 / 207). Total: 3,583 games and 67,605 tracks.
- On October 11, the hosted Nintendo Game Boy set was replaced by all 256 compressed UACs in `Audio/JohnS/VGMRIPS/Nintendo Game Boy` (46,191,982 bytes). The selected complete playlists publish 3,937 VGM tracks; all packages contain PNG artwork. The unrelated Game Boy Mono set (32 packages, 795 tracks, 896,731 bytes) was removed from the server. Local source files remain unchanged; old history snapshots are retained without track-ID remapping.
- On October 11, four VGMRIPS arcade minor sets were published: Konami (97 packages / 1,861 tracks), Namco (96 / 1,991), SegaSys (118 / 1,455), and Taito (116 / 1,567), totaling 427 compressed UACs (665,135,497 bytes) and 6,874 VGM tracks. Arcade (Mixed) and Arcade (Capcom) remain hosted as separate groups. See `ai/reports/spcboy-vgmrips-gameboy-and-arcade-minor-2026-10-11.md` and its JSON manifest.
- Each October 11 import manifest records source paths, byte lengths, SHA-256 values, playlist choice, and package counts. UAC manifests and compressed-payload BLAKE3 values were checked; selected VGM durations come from total-sample counts read through seekable frames. Every new source remains compressed, and no pre-encoded audio is kept. The deployed gallery cache covers 2,967/3,583 albums: 21,030,582 bytes of 240px tile WebP and 32,307,024 bytes of 1,200px detail WebP. Its rebuild reported zero unreadable UAC packages. No old server files are retained for rollback; there is no duplicate game-payload backup.
- The October 10 import reports retain the source and package detail for the full `Arcade (Mixed)` and `Arcade (Capcom)` catalogs and the complete NES replacement. The mixed arcade import added 467 UACs (352,741,327 bytes) / 6,894 tracks; Capcom added 99 (186,938,646 bytes) / 2,999 tracks; NES added 531 (40,279,392 bytes) / 7,024 tracks. NES IDs were regenerated and old NES favorites/history are not remapped. See the matching `ai/reports/spcboy-vgmrips-*-2026-10-10.*` files.
- The authenticated `/audio/spcboy/<track-id>/` `StreamingHttpResponse` materializes only the selected member to a request-scoped temporary file, decodes VGM/VGZ with the bundled libvgm streamer and GBS/NSF/NSFE/SPC with libgme, then streams AAC at the global bitrate through FFmpeg. Monthly usage accounts actual streamed bytes. Source packages and catalog live outside the app tree under `SPCBOY_MEDIA_ROOT` (default `/var/lib/precalc-admin/media/spcboy`). Never expand the library ahead of playback, store pre-encoded copies, expose archive paths in API responses, or bypass Django with direct static delivery.
- `FavoriteAlbum` stores account-scoped album favorites by opaque console/game ID; `/spcboy/favorites.json` syncs both track and album IDs. In the player Favorites view, an album favorite includes all of that album's tracks, and Shuffle Favorites starts a shuffled playlist while retaining the existing Up Next items not already in the selection. Member profiles include album favorites with timestamps; their Play album controls fetch only that album's public display metadata from the authenticated `/spcboy/album/<album-id>.json` endpoint and replace the current playlist. Track-card Play actions use the same endpoint and start at the selected track. `playAlbumFromControl` owns that shared click path, while modified anchor clicks retain browser behavior. Selecting an album replaces all unrelated Up Next entries. The Gallery view shows only albums with cached artwork, grouped by console; opening a tile shows its tracks and can play the full album. Its accessible zoom range is 50–150%, scales minimum tile size, and persists per account/browser. Gallery tiles use aspect-preserving WebP thumbnails capped at 240px and a 1,200px detail rendition for mobile album view; artwork is never enlarged beyond source dimensions and uses .25rem corner radii.
- The October 11, 2026 small-console VGMRIPS import added 370 compressed UACs (184,182,935 bytes) and 6,377 tracks across Atari 5200/7800/Lynx, Intellivision, NEC TurboGrafx-16, Neo Geo Pocket/Color, Nintendo Famicom Disk System, Sega CD/Pico/SG-1000, Vectrex, Virtual Boy, and WonderSwan/Color. Arcade, Computers, Neo Geo arcade, and the 280 MB Sega 32X root were excluded. At the time of this import, the catalog had 2,235 games and 37,362 tracks. Source paths, per-package SHA-256, and live verification belong in `ai/reports/spcboy-vgmrips-small-console-sets-2026-10-11.json`; remove the temporary transfer TAR after publishing the packages.
- For new SPCBOY UAC imports, prefer `Audio/JohnS/VGMRIPS/<system>` when it contains the matching console and game. If VGMRIPS has no match, search the other collections under `Audio/JohnS/` before falling back to another source such as `Audio/JoshW/`. Verify console, title list, and explicit per-track play/fade timing before selecting an alternate package; matching filenames alone are insufficient. Keep source UACs compressed and record each selected source path, byte size, and hash in the import manifest. VGM duration comes from the member header's total-sample count. For NSF/NSFE/GBS subsongs, store the decoder's zero-based playlist index; NSFE `sourceTrackIndex` can be a source song ID (for example 74) that libgme cannot use as a decoder index. Do not publish subsongs unless their selected indexes decode.
- `SPCBOYPlaybackHistory` stores one row per authenticated user and playback UUID after the response produces its first encoded audio bytes. Reusing that UUID across pause, seek, retry, and resume prevents duplicate rows. Each row stores the user relation, track ID and display snapshots, plus play time; it stores no source path, IP, or device identifier. Every signed-in user may read the shared paginated `/history/` page. `/spcboy/recents.json` returns the same event snapshots filtered to the current account, paginated by 100 newest visible plays. Its POST action accepts an owned event ID and creates an account-scoped `SPCBOYRecentHidden` record. Hidden events disappear only from that member's Recents API; the shared History row and public history remain unchanged. Account deletion cascades to that account's playback history, hidden-Recent records, and Now Playing row.
- `/spcboy/catalog.json` returns the playable library shell only: canonical console names, game names, per-game track counts, album IDs, and cached artwork URLs. The browser builds the tree and Gallery from this compact summary, then fetches a game playlist from `/spcboy/album/<album-id>.json` only when that game is opened or played. The title, artist, and length rows are therefore created on demand instead of eagerly rendering every hosted track. `/spcboy/search.json` searches playable tracks across title, artist, game, and console with the app-owned SQLite FTS5 trigram index at `SPCBOY_SEARCH_INDEX_PATH` (default `/var/lib/precalc-admin/spcboy-search.sqlite3`), rebuilt during deployment and lazily refreshed when catalog size or nanosecond mtime changes. Query terms are ANDed independent of order; Unicode marks are folded and short terms use escaped substring matching. Search returns pages of 100 metadata-only rows, materialized into the visible groups; search remains server-indexed and independent of which games have been opened. `/spcboy/favorites/playlist.json` returns at most 100 of the signed-in member's favorite tracks and tracks from favorite albums per request, with `nextPage`; phone Favorites renders cards, desktop Favorites uses the sidebar plus configurable playlist table, and both load another page only on request. Shuffle Favorites explicitly loads all pages before shuffling. `/spcboy/recents.json` returns 100 visible rows per page; its POST hide action affects only the member's Recents view, never shared History. `/spcboy/navigation.json` uses the index source order to fetch one adjacent track for shared-player Next/Previous without preloading the entire library. Archive/member paths remain solely in `catalog.json` and are never returned by display APIs. Artist is a playlist column on desktop.
- SPCBOY shares one loading notice for the initial catalog and Gallery. It is centered above a dimmed screen while active. Gallery entry, console changes, and additional tile pages eagerly decode at most eight thumbnails before dismissing the notice; album selection uses the same notice while its on-demand track list loads. Keep the rest of each page lazy to bound image and catalog work.
- Member portraits, track rows, dates, and timestamps across profiles, Accounts, History, Favorites, and sign-in/session logs, and dynamic Recents use the shared partials in `templates/accounts/partials/` and `SiteComponents` in `static/accounts/site-components.js`. Keep one Detroit timestamp text format (`Oct. 16, 01:32 PM`) and one human date format (`Oct. 16, 2026`); page-specific layout and responsive sizing belong in the owning page styles, not duplicate component markup. The desktop player dock grid must define aligned `main`, `status`, and `clock` areas; its status is visible at idle on desktop SPCBOY, and busy state must use the shared player status API so the top Play control ring tracks the same buffering/preparation state.
- All authenticated pages share site navigation in `base.html`. On desktop, the top bar has compact status-font text links for SPCBOY, Listening, Favorites, Recent, and Profile at the left, with Queue and the Menu hamburger at the right. Keep profile images, activity stats, and admin shortcuts out of that row. The hamburger opens the shared tabbed drawer on Navigation by default. Navigation groups core player/account routes, then puts owner-only Admin and Other sites in separate divider sections. Phone controls keep their established positions and its Menu opens Options first. Do not add another site menu or profile icon to the SPCBOY library toolbar. The desktop SPCBOY shell uses a compact monospace layout with no duplicate player title or album-info strips. Its sidebar header is one full-width row with expanding search first, then square icon-only Library, Favorites, Recent, and Gallery controls, Fold all, and contextual Shuffle Favorites. The desktop dock is visible only on SPCBOY. Desktop Favorites and Recent text shortcuts use the shared player-view event to switch the player view without dropping playback state. The Profile route is a text link in the desktop bar and remains linked from the drawer identity. Player options and the full site navigation share the tabbed Menu drawer; owner tools appear only in the Admin section. Desktop and phone same-site navigation use the shared page shell, preserving active playback, queue state, and the page-load session limit while swapping page content; desktop and phone retain separate responsive layouts. Track links on other pages navigate to `/spcboy/?play=<trackId>`, and album links navigate to `/spcboy/?album=<albumId>`; On phones, Previous/Play/Next, Queue, and Menu remain in their existing top bar positions; compact site navigation, Profile, and owner Site tools remain in the Navigation tab, and Volume is in Sound settings. The SPCBOY phone header order is menu, Previous/Play/Next, Queue, and Menu and Options; Profile and owner Site tools are in the left navigation drawer. The bottom status bar shows the current track, preparation/status feedback, and a right-aligned `elapsed / track / playlist` clock on every phone page. The playlist duration is the current track plus Up Next; use effective track durations so Long Play updates both duration fields immediately. Elapsed time is the source offset plus `HTMLAudioElement.currentTime` multiplied by the effective source-decoder speed, including after stream restarts. The phone SPCBOY page uses one library toolbar row for search and the Library, Gallery, Favorites, and Recent view controls, followed by contextual tree actions. Keep that toolbar separate from the scrollable tree or selected single-pane view; it must not reserve a blank toolbar row or hidden desktop pane. Favorites and Recent use matching phone card rows with 60-pixel square album art, compact track metadata, and rounded image corners. Keep all tree branches folded at startup and continue fetching album tracks only when a game is opened or played. Desktop Favorites and Recent stay in the two-pane shell: its sidebar shows favorite games, and its playlist uses the configurable desktop columns with paged favorites; selecting a game scopes the playlist, while no selected game shows all loaded favorites. Phone Favorites and Recent share the card renderer, but have different swipe actions: Favorite swipe reveals removal of that track favorite; Recent swipe hides the event from only that account's Recents. The shared History record must remain intact. The desktop Menu drawer uses one tab strip for Navigation, Sound, Interface, and Playback; Interface contains the desktop-only Playlist column visibility controls; the panel slides in from the right. On phones, the shared panel fills the screen with safe-area insets; one Navigation/Options toolbar sits above a scrollable stack of Sound, Interface, and Playback sections. Both layouts expose Long Play, Fade Out, Native format speed, and the 10-band equalizer. There is no seek slider or codec/bitrate readout. Playback, including queued tracks, must stop at the owner-configured whole-minute limit (1–1,440 minutes) from the last full document load; same-site navigation must not reset the limit, and the stream handler must enforce the signed token's same cutoff if the browser timer is suspended. The split tree and playlist sit below the sidebar header. Desktop starts with every console and game disclosure folded while loading the initial selected album into the playlist; the Fold all button closes every disclosure without clearing the playlist selection. Search results appear in the playlist without auto-opening matching branches. On phones, the tree also starts folded and allows at most one expanded console and one expanded game at a time; search and Favorites use the flat playlist pane and page 100 tracks at a time. Gallery renders up to 80 art tiles per page, lazy-loads and asynchronously decodes images, and releases detached cards when changing consoles or leaving Gallery. These bounded result and tile pages, plus lazy album fetches, are the browser-overload guardrails; do not eagerly open every match or materialize the whole catalog's track rows. Gallery title buttons use regular UI text, and each Gallery title has a small adjacent album-favorite control. Desktop SPCBOY playlist rows and desktop Favorites rows expose Favorite, track number, Title, Game, Artist, System, and Length columns. Options stores per-account column visibility, column order, and manual widths. Default column widths use available playlist space, not track text; empty metadata headings hide automatically without changing saved visibility. Keep archive filenames and source paths private, and leave the sidebar and phone row layouts compact. Appearance follows the device color preference by default, with per-profile Dark and Light overrides; do not put a theme toggle in the site header. Site dates and Recent timestamps use `America/Detroit`; monthly stream quotas and their reporting periods remain UTC.
- On desktop SPCBOY, transport, EQ, Long Play, Volume, Queue and Options share the sidebar toolbar. On phones, transport lives in the persistent bottom dock; Queue and Options remain in the top bar. The bottom dock shows the current track, preparation/status feedback, and the right-aligned `elapsed / track / playlist` clock. The playlist clock sums the current track and Up Next using each track's effective duration; its track and playlist totals reflect Long Play immediately. Elapsed is the stream source offset plus `HTMLAudioElement.currentTime`, including after stream restarts. The queue, settings, and volume panels remain mutually exclusive. On phones, Previous/Play/Next, Queue, and Menu and Options remain in the site top bar; Profile and owner Site tools are in the left navigation drawer, and Volume is in Sound settings. The bottom status bar shows the current track, preparation/status feedback, and playback clock on every page. Options reuses one tabbed panel: it slides in from the right on desktop and fills the screen with safe-area insets on phones. On phones, omit field helper copy; keep units with their field labels before aligned controls. The settings tab underline shares site motion timing and reduced-motion behavior. Long Play, SPC fade seconds, and fractional speed are configured there. SPC fade is a saved 0–30 whole-second account preference (default 5); changing it restarts the current stream from its current position so the new fade applies to that request. Volume is saved in the account preferences in 21 levels (0–20, 5% per step); requests carry the selected value and FFmpeg applies it before AAC encoding. Changing volume restarts active playback at its current source offset. The opt-in EQ lazily creates a browser Web Audio chain for the same-origin media element after AAC decoding; resume its context from the initiating gesture and leave all band gains at zero when EQ is off. Server-side volume keeps 5% steps consistent on iPhone Safari. There is no seek slider or codec/bitrate readout. Playback, including queued tracks, must stop at the owner-configured whole-minute limit (1–1,440 minutes) from the last full document load; same-site navigation must not reset the limit, and the stream handler must enforce the signed token's same cutoff if the browser timer is suspended.
- On mobile browsers, create or resume the Web Audio graph from the playback-control gesture before deferred album requests; EQ, client volume, and Faded Skip require a running context. Keep the direct media output fallback when graph setup fails.
- Main navigation, player tabs, and settings tabs use the shared site motion token for their sliding indicators; honor `prefers-reduced-motion`. Desktop library selection follows the mouse with its animated highlight and selected track underline; the playlist underline fades when a different track is selected and does not replay during resize or scrolling. Phone library selection uses stable selected-row backgrounds and a left accent; hide the floating sidebar and playlist indicators, and clear pointer-hover state when entering the phone layout.
- The shared player owns an in-memory Now Playing playlist. Its queue control opens a right-side slide-over drawer (desktop: up to 32rem; phone: up to 85vw) with the current track and Up Next. A 25%-black scrim closes it on outside tap; Escape and the rounded-square close button also dismiss it. The count and playback clock include the current track plus queued tracks. Playing a track from the SPCBOY explorer resolves its full album, starts at the selected track, queues the rest in album order with wraparound, and retains unrelated queued items afterward. Changing the explorer view does not mutate or navigate this playlist. Its end stops playback without falling through to explorer order. Queue removal and Clear up next affect only upcoming tracks. Previous follows the current playlist's play history. External track controls (`data-site-play-track`) on phones insert the chosen track at the queue front and play it immediately, retaining the remaining queued tracks in order. Album playback creates a run of the album's tracks; Shuffle Favorites randomizes its selected tracks with the same queue rule. Desktop track links outside SPCBOY navigate to the player with `?play=<trackId>` and start that track's album playlist; desktop album links use `?album=<albumId>` and start that album playlist there. Same-tab activity track controls still insert and play their chosen track while preserving the rest of the queue.
- Main navigation, player drawers, and selection motion share the 240ms `cubic-bezier(.2, 0, 0, 1)` site motion tokens. Keep desktop and mobile layouts explicit in their responsive rules, use `--sb-radius` for multi-album playlist group headers, reuse the shared artwork-aware `track_card.html` for Favorites, profiles, Now Playing, and Played, and honor `prefers-reduced-motion`.
- `build_spcboy_search_index` rebuilds the derived FTS index. It can be discarded and recreated from the hosted catalog; it is not authoritative music data. The current 458 MiB droplet OOM-killed an in-place index refresh and also OOM-killed a Gunicorn worker during a backup run while users were active. For large catalog changes, build the SQLite index on a larger host, then install it only after its `catalog_state` size, nanosecond mtime, row count, and SQLite integrity match the live catalog. Run gallery-cache generation with the service stopped; schedule backups in a low-traffic window and check memory if the app is busy. Verify the service is active after maintenance.
- `/history/now-playing.json` includes the catalog `trackId` and only currently playing listener cards plus the online count. On phones, same-tab activity track controls use the shared player queue. A direct `/spcboy/?play=<trackId>` URL resolves the ID against the authenticated catalog, selects the matching row, removes the query parameter from the address, and starts that track's album playlist. A direct `/spcboy/?album=<albumId>` URL resolves the album against the authenticated album playlist endpoint, removes the query parameter, and starts that album playlist. Stale or unknown IDs do not issue audio requests. Browser autoplay restrictions may require the user to press Play after direct navigation.
- The Chat page, navigation links, message APIs, and unread badge have been removed. `/chat/` redirects to SPCBOY. Existing `MemberChatMessage` rows, model, and migration remain stored; the site no longer exposes them.
- SPCBOY SPC members default to a 180-second total playback window with a configurable 0–30 second fade, defaulting to 5 seconds; the streamer receives the remaining play time plus that fade. The setting is saved in account cloud preferences and travels in `spcFade` on stream requests. The server accepts only whole seconds from 0 through 30 and ignores this option for non-SPC members. The catalog endpoint reports the same 180-second duration to the browser. For SPC files, disable libgme silence-based early termination and autoloaded metadata playback limits, so the configured duration governs playback. Long Play accepts whole seconds from 0 through 86,400. Zero is unlimited musical timing, bounded by the owner-configured whole-minute page deadline (1–1,440 minutes) and streaming quota. The deadline is minted into the signed page-load token and passed to the browser; new document loads receive the current SiteSettings value. Legacy tokens without this field retain 60 minutes. The decoder receives a bounded remaining-session output window for zero, covering the selected source-decoder tempo up to 2× with no musical fade; the HTTP loop remains the independent wall-clock guard. Finite timing includes a fade clamped below the requested total. The duration editor accepts seconds, M:SS, and H:MM:SS, defaults new users to 180 seconds, and migrates existing saved minute values. Disabled duration edits do not restart streams; an unchanged Enter/blur commit must not restart twice. Client clocks show infinity for unlimited track/queue durations. Decoder-local fades must not terminate Long Play: apply one absolute output fade across loop restarts, leaving normal playback timing unchanged. The web equalizer uses ten peaking bands centered at 31, 62, 125, 250, 500, 1k, 2k, 4k, 8k, and 16k Hz; each gain is clamped to half-decibel steps from −12 to +12 dB. Persist enablement, gains, and presets in account-scoped cloud preferences; local storage is a one-time migration source only. Reduce output headroom by the largest positive gain. EQ applies after AAC decoding and never changes the requested stream, AAC bitrate, or server bandwidth. Native format speed is a reduced fraction on the 1/64 rate lattice from 1/2 through 2 inclusive. Reject malformed fractions, non-lattice rates, and out-of-range values without applying or persisting them; retain compatibility with existing decimal local-storage values when they map to the lattice. Persist a separate `playbackSpeedEnabled` boolean in account cloud preferences; the Playback checkbox and toolbar control share it. If it is unset, enable an existing non-1 native rate for compatibility; default 1× starts disabled. Send the configured native fraction to the stream handler and apply it in the source decoder before AAC encoding: libVGM tempo for VGM/VGZ and `gme_set_tempo` for SPC/NSF/NSFE/GBS. The browser audio element stays at 1×; there is no browser-side encoded-rate preference. Source-position mapping and media-session rate follow the enabled native decoder tempo, and fade wall-time uses that same native rate. Restart an active stream at the same source position when the enabled native rate changes.
- SPCBOY's decoder uses the bundled VGMBoy libvgm bridge for VGM/VGZ and libgme for GBS/NSF/NSFE/SPC. Each request materializes just its selected archive member in a temporary file before starting the decoder and FFmpeg AAC encoder; AAC audio is generated during playback and is not saved as a converted track. VGMBoy prepares the selected archive member through its shared Linux helper, retaining indexed UAC reads and dependency preparation behind that boundary. Django does not decompress archives. Install the runtime and host archive tools through `private-admin-setup.sh`; the browser response is AAC-LC ADTS at the global bitrate with `Content-Type: audio/aac`, `Accept-Ranges: none`, and no MP4 container or stored encoded file. Explicit source-position changes restart decoding at the requested source position. One decoder and encoder span native loop boundaries; looped VGM files must not fall back to whole-file restarts on unexpected EOF. The stream handler discards exactly the first complete ADTS frame from each new encoder as AAC priming before byte accounting and streaming. The browser uses MSE `audio/aac` parsing, which generates timestamps for ADTS frames. The browser applies volume steps 0 through 20 through the shared Web Audio output gain, combined with EQ headroom and smoothed over 35 ms. Volume adjustments preserve the current media URL, decoder state, and buffer, independently of iOS Safari’s media-element volume property. The signed-in account preferences remember volume across clients. Browsers without a working Web Audio graph retain encoded-volume fallback: the endpoint accepts steps 0 through 20 and applies the 5% gain increment in FFmpeg; changing that fallback volume restarts at the current source offset.
- Logout records the session end before Django flushes the session. Passkey enrollment signs in the account only after the credential is stored.
- `HTTP_X_REAL_IP` is trusted only because Gunicorn binds loopback-only and the admin Nginx virtual host overwrites the header with `$remote_addr`. Do not expose Gunicorn directly or accept client-supplied forwarding headers.
- SSH remains key-only and distinct from web account management.

## SBONLINE Playback-Core Boundary

- `VGMBoyArchiveCore` owns primary playback source preparation. Django passes
  the catalog-selected original archive/member to `vgmboy-prepare` through
  `accounts/vgmboy_prepare.py`; the SBO adapter handles legacy manifest-less
  Master `.uac` tar payloads when the helper rejects their format.
- The Linux package is built by VGMBoy's manual Ubuntu 24.04 workflow and
  staged as `SBONLINE/ops/server/artifacts/vgmboy-prepare-linux.tar.gz`. It contains the
  executable, required Swift runtime libraries and `SOURCE_REVISION`, not a
  compiler or pre-encoded media. Deployment stores immutable runtime versions
  by artifact SHA-256 under `/opt/precalc-admin/lib/vgmboy-prepare/` and atomically
  replaces `/opt/precalc-admin/bin/vgmboy-prepare`. App release sync cannot remove
  them. Missing/unlaunchable runtimes stop deployment or fail playback explicitly.
- Preparation inherits configured `SPCBOY_TAR`, `SPCBOY_ZSTD`, and `SPCBOY_7Z`
  paths through VGMBoy's host-tool inputs. Enforce a 60-second wall deadline
  and 128 MiB stdout limit while reading. Request-owned TMPDIR, process-group
  termination and child reaping reclaim partial output and nested tool scratch
  on failure. For manifest-less Master `.uac` files that are Zstandard-
  compressed tar archives, the SBO-owned adapter streams only the selected
  member through the configured `zstd` and `tar` tools; it writes no persistent
  extracted tracks.
- Django still owns authentication, catalog validation, quotas, request lifetime
  and AAC HTTP delivery. `SBONLINE/server/streaming/` remains the Linux PCM
  decoder adapter with pinned upstream sources in `UPSTREAM.md`; archive-helper
  adoption does not imply a full native playback-core port.

## SBONLINE Presentation Boundary

- `sbonline.css` owns player geometry; `sb-theme.css` supplies the charcoal/cyan
  site theme, shared `.sb-toolbar` geometry, controls, and full-workspace drawer.
  Account pages use the same theme. Profile no longer exposes light/system skins;
  its existing theme form field is submitted as dark without changing the schema.
- `sb-interface.js` owns account/browser presentation preferences and one clipped,
  pointer-transparent hover/focus indicator. Motion uses the SB2 200ms default
  and cubic-bezier(.2,0,0,1), with reduced-motion precedence. Audio remains separate.
- `site-player.js` retains the sole audio element and engine. Desktop SPCBOY
  mounts existing transport/actions in the sidebar. Other pages and phones use
  their shared hosts. Page leave restores persistent controls before detachment.
- The authenticated `/spcboy/` document is user-specific and must be returned
  with `never_cache`; version query strings on its page assets must change when
  those assets change so mobile Safari cannot keep an older shell.
- EQ enablement, gains, and presets use `SBOProfileStorage` and the existing
  account-scoped cloud preference endpoint. Browser storage is only a one-time
  migration source; do not add a second audio graph or preference table.
- `site-navigation.js` preserves playback and caches the detached SPCBOY workspace
  across desktop and phone navigation. Incoming page styles precede shared skins.
  Base scripts marked `data-site-global` run once; only page-specific scripts
  are reloaded after a shell swap. A stale response or pending page script must
  not replace or initialize after a newer navigation. Cached workspace listeners
  must ignore detached DOM when measuring or saving.
- `spcboy.js` stores versioned `workspaceTabs` under the existing account prefix.
  Bound it to 24 validated contexts; save stable album IDs rather than catalog
  indexes or track metadata. Restore browsing state without starting audio.
  Tabs reuse the same catalog, loaded album promises, favorites, and player.
- Public columns fit every rendered playlist row, deduplicating measurements in
  the shared SB2 typography helper. It uses rendered text (including casing,
  letter spacing and font features), a bounded measurement cache and batches of
  at most 256 probe nodes. Ordinary columns and Title retain their content width;
  empty metadata columns hide without changing saved visibility. Header/body use
  identical grid widths/insets and canonical motion; manual pointer resizing
  bypasses easing and reclaims capture on cancel/loss. Observe viewport size,
  not animated content width, and never measure detached cached workspaces.
- Year and Dumper are supported public columns. The hosted catalog currently
  omits those fields, so they stay automatically hidden until publication supplies
  metadata. `_public_spcboy_track` is the allowlisted projection for albums,
  favorites, track detail, search and navigation; paths/archive identity stay
  private. Search enrichment retains the FTS schema and paged-result limits.
- Portable presentation assets `sb-presentation.css` and `.js` are copied from
  VGMMan/SB2, not maintained independently. Run SB2's
  `python3 scripts/sync-online-presentation.py` after editing the canonical files;
  `--check` fails on drift. They own bottom fades, playing bars, text measurement
  and column-drag motion only. Keep catalog, audio, auth and persistence in each
  app's adapter.
- Desktop Row gap defaults to 1 whole pixel (1–32) for sidebar and playlist;
  phone hit targets remain larger. All column headings are centered. Desktop
  album leaves hide their chevrons; consoles and phone albums keep disclosure.
  Column order and manual widths persist per account. Drag headers to reorder
  or drag their edges to resize; default widths do not measure track text.
- All desktop views share a two-column workspace. Gallery reuses the catalog's
  console folder summaries in the sidebar; selecting a folder filters the artwork
  grid without exposing nested game rows. Phones use the Gallery console dropdown
  and open tile selection in an in-place cached-artwork and tracklist detail view;
  desktop tile selection exits Gallery and uses the normal album selection view. The
  saved-tab strip is desktop-only; mobile keeps the browsing views without tab management.
- EQ, Long Play, and volume aliases operate existing settings. Do not create a
  second graph, stream format, or preference namespace for those audio settings.
- Options/Queue become inert while closing; main/header become inert while open.
  Focus returns to the opener; close timing follows the presentation preference.
  Expiry must also release background inertness.
- Stop resets source offset and retains the track/queue. Hosted identifiers,
  CSRF, source isolation, and playback admission remain unchanged.

## Failure Boundaries

- A missing DNS A record prevents reliable HTTP-01 certificate issuance. The current public site's HSTS policy includes subdomains, so normal admin access must begin only after HTTPS is live.
- vnStat cannot backfill interface traffic from before its database began collecting.
- The Usage page's vnStat chart sums received and sent bytes on whole-droplet `eth0`; it cannot attribute traffic to a virtual host. Compare `MonthlyUsage.site_bytes + MonthlyUsage.media_bytes` with vnStat `tx` only, and expect a gap for public-site responses, static assets, anonymous requests, headers, TLS, and network overhead. Do not infer per-account usage from vnStat.
- Provider billing totals can differ from interface totals.

## Files

- `SBONLINE/ops/server/build_bom_site.py`
- `SBONLINE/ops/server/sbonline-deploy.sh`
- `SBONLINE/server/precalc_admin/settings.py`
- `SBONLINE/server/accounts/views.py`
- `SBONLINE/server/accounts/spcboy_catalog.py`
- `SBONLINE/server/accounts/catalog_search.py`
- `SBONLINE/server/accounts/spcboy_gallery.py`
- `SBONLINE/server/accounts/spcboy_timing.py`
- `SBONLINE/server/accounts/management/commands/build_spcboy_search_index.py`
- `SBONLINE/server/accounts/management/commands/build_spcboy_gallery_cache.py`
- `SBONLINE/server/accounts/management/commands/restore_invitation_code.py`
- `SBONLINE/server/accounts/passkeys.py`
- `SBONLINE/server/accounts/models.py`
- `SBONLINE/server/accounts/migrations/0014_member_profile_avatar_presets.py`
- `SBONLINE/server/accounts/migrations/0015_member_profile_initials_only.py`
- `SBONLINE/server/accounts/migrations/0006_passwordless_passkeys.py`
- `SBONLINE/server/accounts/migrations/0007_passkey_username_setup.py`
- `SBONLINE/server/accounts/migrations/0008_simpler_join_openings.py`
- `SBONLINE/server/accounts/migrations/0011_member_profiles_social_and_invite_throttle.py`
- `SBONLINE/server/accounts/migrations/0012_now_playing_and_post_track_snapshot.py`
- `SBONLINE/server/accounts/migrations/0017_spotlight_posts.py`
- `SBONLINE/server/accounts/migrations/0018_spotlight_votes_and_commentary.py`
- `SBONLINE/server/accounts/migrations/0019_monthly_audio_stream_quota.py`
- `SBONLINE/server/accounts/migrations/0020_member_profile_site_persona.py`
- `SBONLINE/server/accounts/migrations/0021_favorite_album.py`
- `SBONLINE/server/accounts/migrations/0022_member_profile_high_quality_audio.py`
- `SBONLINE/server/accounts/migrations/0023_remove_memberprofile_high_quality_audio.py`
- `SBONLINE/server/accounts/migrations/0024_access_key_credential.py`
- `SBONLINE/server/accounts/migrations/0035_remove_spotlight_feature.py`
- `SBONLINE/server/accounts/management/commands/issue_passkey_recovery.py`
- `SBONLINE/server/static/accounts/admin.js`
- `SBONLINE/server/static/accounts/site-components.css`
- `SBONLINE/server/static/accounts/site-components.js`
- `SBONLINE/server/static/accounts/site-player.js`
- `SBONLINE/server/static/accounts/player.css`
- `SBONLINE/server/requirements.txt`
- `SBONLINE/server/accounts/usage.py`
- `SBONLINE/server/templates/accounts/`
- `SBONLINE/server/templates/accounts/partials/member_avatar.html`
- `SBONLINE/server/templates/accounts/partials/member_avatar_content.html`
- `SBONLINE/server/templates/accounts/partials/profile_identity.html`
- `SBONLINE/server/templates/accounts/partials/track_display.html`
- `SBONLINE/server/templates/accounts/partials/record_time.html`
- `SBONLINE/server/templates/accounts/partials/record_date.html`
- `SBONLINE/ops/server/sbonline-setup.sh`
- `SBONLINE/ops/server/private-admin.service`
- `SBONLINE/ops/server/sbonline.nginx.conf`

Playback recovery is account-scoped in `MemberProfile.spcboy_preferences` and
syncs through `/spcboy/preferences.json`. Browser storage is only a one-time
legacy import and is cleared after a successful cloud save. Keep at most 500
queue/history entries and store metadata, absolute position, playlist state and
playing intent; never persist signed media URLs. Restoring creates a new
playback UUID and signed page token. Position saves are throttled to 15 seconds,
with flushes on page leave/page hide, so another client may resume from a recent
saved point rather than the exact last sample. Autoplay denial leaves a usable
Play control and restored position.
AAC-LC in ADTS is the only output format. The client expiry clock
starts at player initialization; signed session and quota enforcement remain authoritative.

## AAC streaming transport

`aac-stream.js` attaches MediaSource (or ManagedMediaSource) to one audio element
using the `audio/aac` ADTS byte stream.
Serialize bounded appends, evict old media, and backpressure above 30 seconds ahead.
Abort obsolete fetches and release object URLs on source changes. Keep one native
decoder and AAC encoder across loop seams. Strip exactly the first complete
ADTS frame from each new encoder before quota accounting and delivery; it is
encoder priming. Do not wrap the stream in MP4 or add codec MIME parameters.
No MP3 fallback or codec selector remains. Unsupported
browsers show an explicit error. Interrupted streams retry at their absolute
position, using the same playback identity; ordinary pause retains the buffer.
Automatic recovery uses at most three attempts with 1/2/4-second backoff; reset
that budget after 30 seconds of healthy playback or an explicit pause. Offline
state waits for the browser online event without spending attempts. Explicit
pause/Stop, track changes and page exit cancel pending retries. Authentication,
quota, expiry and unsupported/decode failures do not automatically retry. Network
headers/body reads have a 45-second deadline, excluding buffer backpressure.
Evict old played audio before appending; on QuotaExceededError evict up to five
seconds behind the playhead and retry identical rejected bytes once. Never discard
unplayed audio. System Media Session controls share the existing playback engine,
absolute position, seek bounds and explicit pause intent. Unsupported actions
are ignored; unlimited Long Play omits finite OS position state.

SiteSettings row 1 owns the global AAC bitrate (96/128/160/192/256 kbps, default
192). Only superusers may save it through Profile → Site settings. Read once per
stream; current encoders keep running. Account quota counts actual bytes.
The ADTS byte stream has no packet timestamps. MediaSource generates its AAC
frame timestamps; do not add an MP4 muxer to the SBO stream command.
ManagedMediaSource disables remote playback; native AirPlay is unavailable there.

Fade Out applies to all formats, matching SB2's playback preference (0–30 seconds;
zero disables). Finite Long Play includes that fade; unlimited has no musical
fade but retains session/quota bounds. Apply one absolute fade across loop seams
and seeks. X-Audio-Duration reports the generated total, keeping the current clock
consistent with a changed fade. The synthetic native-loop check verifies loop
pitch, offset playback, linear fade RMS and timestamp continuity. A minimal NSF
fixture also checks configurable and zero fade on the normal libgme path; disable
its built-in fixed fade and apply the output envelope to all libgme formats.

Desktop Favorites and Recent share the normal two-pane collection layout.
Their sidebar lists only albums represented in the collection, grouped by
console, and selecting an album scopes its playlist rows. Favorites are ordered
oldest-to-newest by add time and expose the Added column; Recent stays
newest-played first and exposes Played. Collection shortcuts clear the album
scope. Online pagination remains bounded.
`sb-mobile.css` owns the final phone layout: a title-free Playing/Library/Gallery/
Options page bar, compact SPCBOY screens, bottom playback dock, and shared player
engine and motion. Playing delegates to the existing site player; the dock remains
available on other authenticated pages and navigation retains the same audio element.
Retired /chat/, /feed/, /community/, /password/change/ routes remain compatibility
redirects. Remaining page templates are referenced; do not delete active profile,
Listening or member Favorites pages as obsolete social placeholders. Spotlight is retired and redirects to SPCBOY.

## Compact web surfaces and live presence

- The persistent player owns its own hidden CSRF form. Its token must survive
  main.page-shell replacement; the CSRF cookie remains HttpOnly. Presence POSTs
  cannot depend on an unrelated form in the currently displayed page.
- Successful presence updates dispatch siteplayer:presence. Listening refreshes
  through a single in-flight request and aborts/removes listeners on page leave.
- track_card.html is the sole card renderer, including live Listening updates
  returned as escaped cardHtml by the authenticated endpoint. Listening inserts
  that same-origin fragment; SiteComponents no longer maintains a second renderer.
  site-components.css owns Listening card geometry. SPCBOY's mobile Now Playing
  view is app-specific and must not replace that shared card. Profile bandwidth is
  collapsed by default; generic profile forms never inherit avatar columns.
- `profile_identity.html` is shared by signed-in and public Profile pages. Keep
  action labels and destinations as caller inputs; `community.css` owns the
  common layout and `sb-mobile.css` owns its phone placement.
- Phone browsing hides workspace-tab management and Stop; desktop persistence and
  controls are unchanged. The mobile page bar is 38px; Library has a 42px search
  row, and Gallery adds a same-size console selector. Playing shows live artwork,
  title, progress, transport, and up to three queued tracks. Portrait geometry is
  square, and mobile album stars sit outside the expandable details width so
  nested track stars align at the same right edge.
- Sidebar depth is 1ch on the actual system-content wrapper; invisible leaf
  chevrons retain their width so label indentation also remains exactly 1ch. Zero-track leaf
  entries hide disclosure arrows; desktop album selectors do not pretend to unfold.
- Full-screen drawer scrims must never be targets of the shared hover indicator.
- SitePlayer.getDuration supplies effective playback timing for the dock clock
  and seek bounds. Playlist and Gallery length labels show the catalog's
  canonical duration and stay unchanged by Long Play or AAC response timing;
  keep response-derived playback duration separate from catalog track data. The
  VGM bridge delegates ending/fade timing to its caller; apply the stream
  wrapper's absolute fade for normal VGM as well as Long Play.

Established presence heartbeats are an atomic UPDATE keyed by user, playback ID
and track ID; only newly announced playback loads/validates catalog metadata.
Use an atomic upsert for new playback to avoid SQLite read-to-write lock upgrades
when multiple tabs announce concurrently. Preserve started_at on ordinary heartbeats.


The mobile presentation keeps site transport in the top toolbar on Library and
Gallery and uses the full controls on Playing; the bottom dock is a 32px readout
plus safe area. Preserve one audio engine when moving controls.
Cards retain the canonical partial with native-size artwork left and all text and
actions right. site-components.css uses 112px desktop / 96px phone art slots and
object-fit: scale-down; do not stretch images, overlay copy or add a full-width
footer. Gallery cache schema 6 stores aspect-preserving 240px tiles and 1,200px detail images without enlarging source artwork; the mobile album detail view uses the larger rendition.
The authenticated desktop toolbar and dock share a compact row across account
pages. `base.html` includes one shared text-link navigation partial for SPCBOY,
Listening, Favorites, Recent, and Profile. Route links use the cyan
accent for the current page. Queue and the drawer button sit at the right; profile
identity and play/online stats appear above the drawer tabs. Owner tools stay in
the drawer. Phones hide the desktop text links and put full-width Player,
Favorites, Recent, community, profile, and owner actions in the shared Navigation
panel. Favorites and Recent buttons dispatch `site:show-spcboy-view` and close
player overlays after selection. Keep topbar route state synchronized through
`site-navigation.js` when same-shell navigation completes. Queue rows keep the
playlist order and split track, game, artist, system, and length into aligned
columns; hide secondary columns on narrow screens.
Mobile browsing is flat and uses the full content width, while honoring device safe areas.

Options reuses one tabbed panel across desktop and phones. Desktop uses a right-side
slide-over drawer up to 44rem wide; phones fill the viewport and slide in from the
right, with safe-area insets. The phone header stays fixed at 44px with one four-item
Navigation/Sound/Interface/Playback toolbar; Navigation and one selected options page
share the scrolling surface, with sections kept inside each page. Keep field labels
and Yes/No buttons in the same 50/50 columns and helper copy compact. Inputs retain
16px text to avoid focus zoom; close/focus trapping and canonical motion stay unchanged.
Back to player links on the current player route close overlays and return to the top
without a document reload or playback interruption.

### Desktop collection playlists

- Favorites and Recents share `renderCollectionPlaylist` and the normal row and
  column renderer. Their sidebar contains only albums represented by the loaded,
  locally filtered collection, grouped by console and ordered by first
  appearance in its playlist. Album selection scopes the playlist without
  switching to Library or fetching the entire album. Favorites retain
  `added_at` order (oldest first) and label the timestamp column Added; Recents
  retain individual events in descending history order and label it Played.
  Clicking the collection toolbar shortcut clears the album scope. Workspace
  tabs retain it by album ID.
- Recents retain individual events in descending history order, including repeated
  plays. Added/Played is a configurable column using America/Detroit. The history
  endpoint adds only public metadata for its 100-event page; removed tracks remain
  visible as disabled history snapshots. Account history and hide-event ownership
  are unchanged. Phones use the same compact row renderer for Favorites and
  Recent. Favorite rows reveal their star on swipe and remove the track when it
  is activated; the mobile row nudges on touch and tracks the finger before
  snapping open. Its remove action is a full-size blue accent square with a
  filled star. Recent rows retain swipe-to-hide. Profile owns bulk removal.
- Collection search filters loaded items locally. Do not send catalog-wide FTS
  requests from Favorites or Recents. Older history remains explicitly paged.
- All ordinary desktop playlist cells inherit the row's single foreground color;
  playing and hover highlights apply consistently to every cell. Keep the shared
  scroll fade independent of text color.

### Mobile selection and theme

- In-player Favorites has no edit toolbar. `profile-favorites.js` owns Select /
  All shown / Remove for the signed-in Profile Favorites pane, including track
  and album selections. Row actions are intercepted only while editing. Server
  failures preserve selections; successful changes refresh Profile through the
  existing SPA navigator and update cached explorer memberships.
- `removeTrackIds` is a bounded, account-scoped Favorites mutation. It removes
  selected explicit tracks and converts affected album favorites to their
  remaining individual tracks atomically, retaining the album's added_at order.
  Unselected songs and other accounts remain untouched. No audio/media is deleted.
  Converted groups may exceed the former 2,000 explicit favorite limit; full
  membership writes remain bounded to 50,000 catalog-valid IDs.
- `sb-theme.css` owns the common Options typography, section bars, field grid,
  square checkboxes and custom slider presentation. `sb-mobile.css` is the sole
  final phone adaptation; do not restore obsolete stacked mobile overrides.
  Volume and EQ use the same slider markup and motion tokens. Labels precede
  aligned trailing controls; mobile text inputs stay 16px to avoid focus zoom.
  The existing drawer lifecycle, focus trap, safe areas, single audio element
  and persistence contracts stay with site-player.js. SPCBOY's mobile page tabs
  and live Now Playing projection belong to `spcboy.html`, `spcboy.js`, and
  `sb-mobile.css`; they delegate all playback and settings changes to the current
  SitePlayer and account preference APIs.

### Mobile shell and Listening

- SPCBOY phones use a title-free page bar with Playing, Library, Gallery, and
  Options. The live Playing view projects the existing track, artwork, progress,
  transport, and queue; it must continue to delegate to the one `SitePlayer`
  audio element. Library and Gallery reuse the current catalog/search state,
  with the Gallery console selector and album detail view. Options opens the
  existing cloud-backed settings panel and adds no preference namespace. The
  site menu retains full Navigation. Other mobile pages keep the persistent
  header search, transport, and Back to player action. No second catalog or
  audio element is created. Browser favorites merge only during the one-time
  legacy import; subsequent loads use server membership.
- Navigation and Options share the tabbed player drawer. Navigation lists
  full-width icon links in one column, with the signed-in member's avatar, play
  count, and online-user count above them. Owner-only links retain their template guard. The panel traps
  keyboard focus and makes main content inert while open; Queue retains its own
  lifecycle. Mobile Gallery has a console selector synchronized with each open
  player tab's selected console.
- Player, Profile and Listening tabs share compact button surfaces, type and active
  treatment. Listening has Now playing / Played tab panels, compact history filters
  and day headings, and smaller phone artwork using the canonical track card.
  The existing single-flight presence refresh and privacy boundary remain intact.

## Unified menu and Admin

The Navigation / Options panels share `site-player.js` drawer focus, inertness,
close and motion handling. Back to player is a same-shell route and does not
reload audio; same-page player links are prevented from causing document reloads.
No independent left drawer remains. Queue retains its separate lifecycle. Owner-only `accounts`
handles global settings and invitations; legacy Profile site-settings requests
route through that same guarded view. Preserve no-store responses and owner guards.
