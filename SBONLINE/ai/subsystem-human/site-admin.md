# Private Admin Space

## Access

The private account and server area is served at `https://admin.pre-calc.com/` and requires a web account. The root page is the passkey portal when signed out and opens SPCBOY after sign-in. The compact charcoal desktop top bar and playback status dock share the same 24px row styling. The top bar has small text links for SPCBOY, Listening, Favorites, Recent, and Profile at the left, with Queue and a hamburger at the right. The hamburger opens a tabbed Navigation and Options drawer. Navigation contains core player and account routes; owner-only Admin and Other sites, including Book of Mormon, appear in separate sections with dividers. The drawer identity card has a 64px profile image and activity stats for total plays and users online. Passkeys and generated login passwords are managed from Profile's Sign-in tab; `/passkeys/` redirects there. The phone Navigation panel contains full-width player, Favorites, Recent, community, and account actions; owner tools appear there for the owner. Site details opens the combined Usage page. The former Overview route redirects to Accounts; Bandwidth and Server open the single Usage page. `/spotlight/` redirects to SPCBOY.

Members join through an owner-issued invitation and register a passkey. From Profile, a signed-in member can generate an optional login password for older devices, replace it, or revoke it. The site shows a generated password only once; it signs in without a username and can be used alongside the member's passkeys.

The owner can open the complete BOM V4 research site from Navigation → Other sites → Book of Mormon. It opens in a new tab so it does not interrupt playback. Online Notes are a read-only snapshot. The main site landing page remains SPCBOY.

The site uses SB2 Charcoal and cyan throughout, including sign-in, profiles,
Listening, Favorites, and owner tools. Desktop SPCBOY has two compact
sidebar toolbars, remembered playlist tabs, a dense monospace track table, and a
split status footer with catalog game/track totals, playback state, and time.
Transport, EQ, Long Play, Speed, volume, Queue, and Options share the first
sidebar row.
Search and library views share the second. Each toolbar uses the same inset and gap.
Authenticated pages share one player dock and one desktop navigation partial.
The desktop bar has small text links for SPCBOY, Listening, Favorites,
Recent, and Profile; the current route uses the cyan accent and shared animated selection. Queue and the drawer
button remain at the right. Its context label shows the current section, not the
selected album. The album stays linked from the bottom playback dock. Navigation
across authenticated pages preserves the player on desktop and phones.
The queue popup follows the playlist's title, game, artist, system, and length
order in aligned columns, with secondary columns hidden on narrow screens.

Phones use a title-free SPCBOY page bar with Playing, Library, Gallery, and
Options. Playing follows the live track, album art, progress, and transport
controls from the single persistent player, and shows the full current album
track list with the active track highlighted. Selecting a row replaces Up Next
with that album starting at the selected track. Library is search-first with
expandable console browsing; Gallery shares the search field and adds a matching
console selector and in-place album details. Options opens the existing
account-saved player settings. The site menu still contains full Navigation,
including Favorites and Recent. Other authenticated pages keep the persistent
player header and Back to player action. Track rows retain larger touch targets
than desktop.
Volume is available in Sound options; its 20 increments are remembered per
account.

A fresh Library tab starts folded; restoring an album opens its console. On phones, opening one
console or game folds its siblings; search and Favorites show paged track rows
instead of unfolding matching branches. Search and Favorites fetch 100 tracks
per page. Gallery adds 80 album tiles per page and releases detached tile images
when changing console or leaving Gallery. Search, Recent, and track data remain
loaded on demand.
The selected Library, Favorites, Recent, or Gallery view is saved in the
signed-in account preferences and restored after a page reload.
Desktop playlist rows show Favorite, track number, Title,
Game, Artist, System, Added/Played, and Length columns. The Options drawer groups
Sound, Interface, and Playback settings. Its Interface tab contains a Playlist
section where desktop accounts can hide columns and drag headers to reorder or resize them;
visibility, ordering, and manual widths sync through the signed-in account preferences. Default
widths use the available playlist space instead of measuring track text. Empty metadata headings
hide automatically without changing saved column choices. Favorites and Recent retain their
Date/Time heading when a timestamp is missing; an empty playlist keeps all configured headings
visible.
Playback includes an optional Faded Skip setting: track changes fade out the
current audio before starting the selected track at its requested position.
Another selection during the fade replaces the pending target.
Column visibility and manual widths update without animation; wide content scrolls horizontally
with its header. The Title heading stays visible when it has content, and
archive filenames and source paths are not exposed. Sidebar and phone track
rows retain their compact layout. Desktop Favorites stays in the normal
two-pane player: the sidebar is filtered to games with favorites, and the
playlist uses the configurable desktop columns with paged favorite
tracks. Selecting a game scopes the playlist to that game's favorites. Phone
Favorites and Recent use matching compact artwork-led rows with square cached
covers and compact track details. Touching a Favorite gives the row a short
nudge; dragging it left follows the finger and reveals a large blue accent
square with a filled star. Activating the star removes that track from
Favorites. Swipe a Recent play left
to reveal its hide action and remove that event from the member's personal
Recent list. Hiding a Recent never
deletes or changes the shared site History record. Favorites and Recent remain
available through full Navigation. The Library screen keeps its search row
separate from the scrollable tree or result pane, and all console/game branches
still start folded. Mobile library track rows
use transparent fills with subtle row separators and no outlines. Sidebar album
favorite buttons are shown on desktop and omitted on phones. Gallery titles use
regular UI text with a small favorite button at the end of each tile. The library
fills the area between site navigation and dock without an inset frame. The mobile
page uses the exact DeepSkyBlue accent. Desktop
Gallery keeps the normal console folders in the sidebar; selecting a console
filters the artwork grid. Mobile Gallery uses a console dropdown. Tapping a mobile
tile opens an in-place album view with larger cached artwork, its track list, and
a Play album action; Back returns to Gallery. On desktop, selecting a tile exits
Gallery and opens the album in the normal player view.
The selected console follows each open player tab. The mobile page opens to
Playing; moving to Library or Gallery does not stop playback. The desktop
dock and top navigation bar share a 24px height and matching charcoal, border,
monospace and muted text styling across authenticated desktop pages. The top
bar keeps the compact text navigation on the left and Queue plus the hamburger
on the right; it contains no profile image, activity stats, or admin shortcuts.
The dock keeps the current track and preparation/status feedback, plus a
right-aligned `elapsed / track length / current track plus Up Next` clock. It
appears only on SPCBOY. Authenticated pages keep the player in the shared site
shell; same-site navigation on desktop and phone swaps page content without
unloading the player, so music and queue state continue across the site. Track
links open that selection in the existing SPCBOY player, and album links open
and play the album there. Desktop and phone keep distinct responsive layouts. The Menu's Navigation section uses one column
of full-width links with icons, while transport moves into the site top
bar; the compact bottom status bar shows the current track, preparation/status
feedback, and the same right-aligned playback clock on every page. Its track and
playlist totals update when Long Play changes. The desktop dock reserves aligned
title, playback-status, and clock columns; its status stays useful when idle
(`Ready`) and reflects `Playing`, `Paused`, preparation, buffering, and stream
errors. The shared Play control shows a loading ring while playback is busy and
a static four-bar equalizer mark while audio is playing. The phone dock keeps
its compact layout and shows transient status messages alongside the same
play-state controls. Desktop Options opens the shared tabbed settings in a right-side slide-over
drawer. On phones, one Navigation/Options toolbar sits above a single scrolling
panel; Sound, Interface, and Playback sections are shown together and Playlist
settings stay desktop-only. Field explanations appear beneath their labels, and
labels and controls share equal-width columns. Same-site navigation preserves the player in its shared page shell on desktop
and phone. Playback stops after
the owner-configured whole-minute session limit (1–1,440 minutes) from the last
full page load; the default is 120 minutes. The stream endpoint enforces the
same cutoff. An expired session exposes a Reload player action in the status bar and replaces
the Play control with Reload player. A failed audio resource is reloaded when
Play is retried; an unexpectedly short stream stays on its track with a retry
message instead of silently advancing through the playlist. The player primes
the Web Audio graph from the playback gesture before deferred album requests.
The player has no progress slider because seeking can interrupt unreliable streams,
and it does not display codec or bitrate details.
The site navigation and library
selectors use a short eased sliding indicator, with motion disabled for reduced-
motion preferences. Desktop library rows follow the pointer and selected track;
phone library rows and tree summaries have transparent fills, with a persistent
accent highlight only on the selected track. Phone toolbars reuse desktop chrome,
button colors, and the canonical 5px radius; player panels retain SB2's dark
surfaces. Selection does not depend on hover or a floating selector. The phone
playback dock uses the same charcoal chrome color as the desktop dock.
Site dates and player recents use Detroit local time;
monthly stream quotas continue to use UTC. Profile portraits, playback-history
entries, shared favorites, and listening activity reuse the same
portrait, compact track-card, and timestamp components. They show track title,
game, console, artist when available, and the common Detroit time format
`Oct. 16, 01:32 PM`;
desktop and phone layouts reposition those components without changing their
content format. Phone keeps compact tree controls
with iPhone safe-area insets; the top controls and bottom status bar honor those
insets. The desktop playlist
selection underline gets a brief fade as it moves to a newly selected track;
reduced-motion settings suppress the effect. The toolbar provides search, All,
Favorites, Gallery, and account-specific Recent plays.
Gallery shows square cover slots with native-size, aspect-preserving artwork and subtly rounded .25rem corners; its per-account tile zoom control ranges from 50% to 150%, adjusts the grid density, and is saved in account preferences. On phones, selecting a tile shows the album detail view with higher-resolution cached artwork and tracks; desktop opens the album in Library. Album stars add every track in that game to Favorites. Favorites
can be played as a shuffled playlist, with tracks already queued afterward
retained. Album favorites also appear with their added time on member profile
pages, where a Play album action adds the album to the shared player queue. The
retired People’s favorites page redirects to the signed-in member’s Favorites
tab. The site-level Listening page combines a live Now Playing section
with paginated Played history, grouped by day. Listening and profile Favorites
and Recents share one artwork card: native-size art on the left and track
details, member/time and actions on the right. The cards show the member, track,
artist, game, console, and Detroit-local time without clipping on phones.
Favorites sync to each account and appear in the shared People’s
favorites page. Public member Profile pages list that member’s favorites and
recent plays and tracked monthly bandwidth; the signed-in user’s Profile page
also contains editing controls. Favorite and stream-history rows show their
recorded date and time. Per-profile bandwidth totals and monthly rows come from
authenticated private-site response bodies, including AAC audio, and exclude
static files and network overhead.
On phones, Profile pages use a compact identity card and full-width Favorite and
Recent rows with small artwork. The profile lists continue through the page
instead of scrolling inside a fixed-height card. Same-tab track controls on Now
Playing, Favorites, Played history, and member profiles load the
selected track's album, start at that track, and replace the current Up Next
list with the rest of that album. The player’s Now Playing control opens a right-side slide-over playlist
drawer on desktop and an 85%-width drawer on phones; its 25%-black scrim closes
the drawer on outside tap. Site navigation, player drawers, and the desktop
selection indicator share the 240ms cubic-bezier(.2, 0, 0, 1) motion tokens and
respect reduced-motion preferences. Playing a track from SPCBOY starts at that
selection and continues through the album in order, wrapping to the beginning
when needed. It replaces unrelated Up Next tracks. Changing the Library,
Favorites, Recent, or Gallery view does not change the active playlist; when
that playlist ends, playback stops instead of advancing through the explorer.
A direct SPCBOY URL with `?play=<trackId>` selects that catalog track and starts
its album playlist.
SPC tracks play for 3:00 by default, including a configurable 0–30 second
fade-out (5 seconds by default). The fade setting is saved per account and
browser. Long Play has natural/off, finite, and unlimited timing: its Yes/No button
enables the saved duration; enter seconds,
M:SS, or H:MM:SS; zero means unlimited. New preferences default to 3:00;
existing minute-based durations migrate unchanged. Finite values support up to
24 hours, while every hosted playback session still ends at the owner-configured
session limit after page load and retains its normal monthly quota. Native
format speed ranges from 1/2 to 2 in exact 1/64 increments. The Playback option
checkbox and desktop Speed toolbar control enable or disable this source-decoder
rate while retaining it.
Its enable state is saved in the signed-in account preferences; existing non-1×
rates remain enabled when upgrading, while the default 1× rate starts disabled.
Long Play overrides decoder-native end signals; non-looping VGM tracks restart
until the selected duration is reached.
VGM tracks with a recorded loop retain their decoder state and loop at that
point without replaying the intro. Audio delivery uses one continuous,
AAC stream across those boundaries. Unexpected
decoder termination inside a native loop reports an error instead of silently
restarting the song.
Volume changes use smoothed browser audio gain and preserve the playing stream
and loop state. Encoded-volume restarts remain a fallback for browsers without
working Web Audio support.
Speed is entered and displayed as a reduced fraction, such as 33/32 or 15/16;
both values are saved in the signed-in account preferences. The desktop dock shows
the current track, preparation/status feedback, and playback clock. The clock
shows elapsed time, the effective track duration, and the duration of the
current track plus Up Next; Long Play updates both duration totals. All
hosted playback streams AAC at the global bitrate, with the same 10 GB monthly account
allowance. The Sound options page has an opt-in 10-band equalizer with 0.5 dB
steps from −12 to +12 dB; enablement, gains, and three preset slots are saved
in the signed-in account preferences and sync across that account's devices. EQ
is applied after AAC decoding.
Volume uses the same audio graph in 5% steps,
including in mobile Safari, without restarting the active stream. Only browsers
without working Web Audio use the encoded-volume fallback described above.
SPC streams disable libgme's silence-based
early-end and metadata playback limits so the configured 3:00 or selected Long
Play window is honored.
The hosted catalog currently has 3,583 games and 67,605 tracks across 25 console groups. Current game/track counts are: Arcade (Capcom) (99 / 2,999), Arcade (Konami) (97 / 1,861), Arcade (Mixed) (467 / 6,894), Arcade (Namco) (96 / 1,991), Arcade (SegaSys) (118 / 1,455), Arcade (Taito) (116 / 1,567), Atari 5200 (2 / 5), Atari 7800 (1 / 10), Atari Lynx (4 / 28), Intellivision (1 / 2), NEC TurboGrafx-16 (243 / 4,205), Neo Geo Pocket (3 / 45), Neo Geo Pocket Color (17 / 380), Nintendo Famicom Disk System (1 / 1), Nintendo Game Boy (256 / 3,937), Nintendo NES (531 / 7,024), Nintendo SNES (1,414 / 32,990), Sega CD (18 / 425), Sega Genesis (19 / 510), Sega Pico (33 / 569), Sega SG-1000 (3 / 12), Vectrex (15 / 21), Virtual Boy (18 / 400), WonderSwan (5 / 67), and WonderSwan Color (6 / 207). Console rows count games/packages; the library readout counts visible games.

The hosted Game Boy collection is now only the compressed VGMRIPS VGM set from
`Audio/JohnS/VGMRIPS/Nintendo Game Boy`: 256 UACs (46,191,982 bytes) and 3,937
tracks chosen from complete playlists. All 256 packages contain embedded PNG
artwork, and all 256 covers appear in the gallery. The former Game Boy Mono
selection (32 packages, 795 tracks, 896,731 bytes) was removed from the server;
its local Audio sources remain untouched. Historical play records keep their
saved titles but are not remapped to the replacement track IDs.

The VGMRIPS arcade vendor sets add 427 compressed UACs (665,135,497 bytes) and
6,874 tracks: Konami (97 games / 1,861 tracks), Namco (96 / 1,991), SegaSys
(118 / 1,455), and Taito (116 / 1,567). The existing Arcade (Mixed) and
Arcade (Capcom) sets remain separate. The new packages were uploaded in source
format; the complete Game Boy and arcade upload is 711,327,479 bytes. Manifests
and compressed-payload BLAKE3 checks passed, installed Game Boy package
SHA-256 values match their sources, and every live catalog archive reference
resolves. No audio members are permanently extracted and no AAC copies are
stored.

The hosted catalog also includes the small root-level VGMRIPS console sets:
370 compressed UACs and 6,377 tracks across 15 systems, adding 184,182,935
source bytes. TurboGrafx-16, Neo Geo Pocket, and WonderSwan are included;
large Arcade, Computer, and Neo Geo arcade roots were not part of this import.
The exact source paths, package SHA-256 values, and per-system counts are in
`ai/reports/spcboy-vgmrips-small-console-sets-2026-10-11.json`.

The deployed schema-6 gallery cache covers 2,967 of 3,583 albums. It stores
21,030,582 bytes of 240px tile WebP and 32,307,024 bytes of 1,200px detail WebP;
the rebuild reported zero unreadable UAC packages. Source PNG artwork remains
inside the compressed UACs. Historical NES, arcade, and small-console import
manifests are in `ai/reports/`.

A play is added to History when
the AAC stream begins; retries and resumes within the same playback do not add
duplicate entries. Account deletion removes that account's playback history. A
play request materializes only the selected member into a temporary file, sends
it through the VGMBoy libvgm/libgme cores, and streams AAC at the global bitrate through
FFmpeg. The library is never expanded ahead of playback and no pre-encoded
track copies are stored.

Album art comes from the first PNG member found inside each UAC package. Source
packages remain compressed; deployment creates a private cache of optimized,
center-cropped 240-pixel WebP thumbnails (lossless for palette art, quality 90
for full-color art). The gallery serves these
cached thumbnails through an authenticated route and does not expose archive
paths.

SPCBOY search covers only playable tracks in the hosted catalog. A private
SQLite FTS5 index at `/var/lib/precalc-admin/spcboy-search.sqlite3` is built from
title, artist, game, and console metadata; every search term must match regardless
of order, and accents are folded for matching.
Results are paged in batches of 100. The first catalog response contains only
console and game summaries, track counts, and cached cover URLs. Track rows load
when you open a game; search uses the server index immediately and displays only
matching pages. Catalog and search responses contain track IDs and display
metadata, never package paths or archive member names.

Profile and Listening are available to signed-in members. The retired
`/favorites/` page redirects to Profile → Favorites. The Chat page and messaging endpoints have been removed; `/chat/`
redirects to SPCBOY. Existing chat message records remain stored but are no longer
exposed through the site. The generic text-and-image Feed and its posting tools have
also been removed; `/feed/` redirects to SPCBOY, while legacy Feed records and media
remain stored but are no longer exposed. The owner Log and shared Listening history
remain available for site activity. The separate Users directory has been
removed; `/community/` forwards to Listening. Listening combines the live
Now Playing cards and shared Played history. Its live status reports the number
of members online without listing every account; only members with a current
track appear in Now Playing. Track activity shows the listener and playback time.
T-101 is the site’s non-sign-in helper persona, formerly known as Luna6. It has
no password or passkey credential.
Profiles support
an editable display name and an optional cropped uploaded picture; without a
picture, the avatar uses the first letter of the display name. Members can
edit their display name and see their join date on private and public profile
pages. Source uploads may be up to 10 MB, including HEIC/HEIF; the site
validates and re-encodes images before storing them under the private media
root. Uploads still work without the browser crop preview; the server center-crops
the original image. Community pages do not expose IP addresses or browser
fingerprints; those remain in the private Log.

The Listening navigation badge shows new plays from other members. Its read
position persists across sign-ins and browsers. The first badge check establishes
the starting position so the existing history does not appear unread. Counts
refresh every 20 seconds while the private site is open.

## Usage and account activity

Usage combines monthly private-site response totals with owner-only droplet status. The droplet section shows monthly vnStat traffic on the public `eth0` interface, memory, disk, load, and uptime. Its monthly transfer is received plus sent traffic for the whole droplet. Compare private response-body totals with sent traffic only; vnStat does not attribute traffic by website. Authenticated account totals exclude public Pre-Calc pages, Nginx static files, headers, TLS, and network overhead, so the two measures are not expected to match and neither is a provider billing total.

The mobile Usage page uses a month-and-year selector that updates in place;
playback remains active. Playback and transfer details start collapsed. Account
usage rows show labeled Site, Audio, Total, and Status values in a compact
two-column layout.

The owner-only Usage page summarizes monthly account traffic, droplet status,
and recovery archives. Its collapsed accounting details explain the 10 GB
monthly audio cap and which response and network costs are included.

The owner Usage page also reports private-admin recovery archives. A root-only systemd timer creates a daily archive containing a consistent SQLite copy, profile/community images, SPCBOY catalog snapshots and gallery thumbnails, and the app environment file, retaining up to 3 successful runs. Compressed game payloads and temporary playback/import files are excluded; restore them from the local Audio source library. The October 11, 2026 archive is mirrored on the FileVault-protected Mac at `~/Library/Application Support/PreCalc Admin Backups/`; refresh that copy when creating an intentional new recovery point. The droplet timer does not copy archives off-host by itself.

Only the owner can inspect the account directory, active browser sessions, login IP/browser details, session fingerprints, the Log, and monthly usage by account. Sign-ins remain active for up to 24 hours after the most recent request and refresh while the account is being used. The Log contains active sessions and sign-in events; event rows show the account's current public profile name when the login username matches an existing account, while unmatched attempts retain the submitted username. Shared SPCBOY playback history is part of the Listening page, alongside current Now Playing tracks. Each play is recorded when its AAC stream begins and retained without an age-based purge; the recorded history starts with the feature's release, and deleting an account also deletes that account's playback rows. Sign-in events are retained from their release onward, and sessions that started earlier have no original sign-in details. IP, browser, and session details expand on demand. Accounts presents compact member cards with 6ch portraits (about 43px at the current avatar font size), active-session details, and owner-only invitation creation/cancellation. It has no frontend controls for deletion, suspension, or passkey recovery; those owner-guarded backend operations remain available for managed administration. Droplet controls remain owner-only on Usage. Session counts represent browsers, not physical devices.

Usage reports monthly authenticated Django response-body bytes on `admin.pre-calc.com`, split between private pages and `/audio/` or `/media/` responses. A separate AAC byte counter enforces the 10,000,000,000-byte monthly per-account stream allowance and carries forward previously tracked audio usage during migration. Public `pre-calc.com` pages are excluded. Nginx-served static assets, headers, TLS overhead, and requests made before collection began are not included. Django-streamed audio on those media routes is counted; direct Nginx or CDN delivery needs separate edge accounting.

## Web Accounts

The owner creates member invite codes from Accounts and shares each code privately with one person. The recipient enters the 8-character alphanumeric code at `/join/`; there is no open-join flow. A member code expires after 24 hours and can be used once. Open codes remain visible and copyable on the owner-only Accounts page with their creation and expiration times; their verification digest and an encrypted copy are stored separately. If a legacy code is recovered out of band, `manage.py restore_invitation_code` reads it from stdin, verifies its digest against exactly one non-recovery invitation, and stores only its encrypted form. Repeated invalid attempts from the same connection trigger a 24-hour pause after five failures in a 15-minute window. The account receives an internal name automatically; members can choose an editable public display name later in Profile. The Accounts page supports invitation creation and cancellation only; deletion, suspension, and passkey recovery have no frontend controls and remain guarded backend operations for managed administration. The owner can still suspend/reactivate members or delete accounts through those backend operations. Deletion ends sessions, cancels open invitations, and removes playback history; sign-in events remain in the Log.

The login portal supports discoverable passkeys with user verification and optional site-generated login passwords; neither method asks for a username. New members receive an internal account name automatically and are signed in after their first passkey is registered. Profile has Profile, Favorites, Recents, and Sign-in tabs; tab selection is kept in the URL. In Sign-in, a member can add or remove passkeys, generate a 256-bit random login password, replace it, or revoke it. The site displays a new password once and stores only its protected digest. Members cannot remove their last registered passkey. Passkey recovery remains owner-guarded backend functionality with no frontend recovery portal; account recovery is handled through managed administration. Web accounts do not create SSH or server-login accounts.

## Files

- `SBONLINE/server/accounts/views.py`
- `SBONLINE/server/accounts/spcboy_catalog.py`
- `SBONLINE/server/accounts/spcboy_timing.py`
- `SBONLINE/server/accounts/passkeys.py`
- `SBONLINE/server/accounts/models.py`
- `SBONLINE/server/templates/accounts/`
- `SBONLINE/server/static/accounts/site-player.js`
- `SBONLINE/server/static/accounts/player.css`

## SBONLINE Player Appearance

- Playlist tabs remember their order, active tab, album, view, search, console,
  and scroll position for the account in the current browser. The plus button
  opens a fresh Library tab. Right-click an album or track for Open in New Tab
  or Open in Background Tab; Command/Control-click and middle-click open in the
  background. Arrow keys move through tabs, Delete closes one, and closing the
  last leaves a fresh Library tab. Browsing tabs does not replace the audio queue.
- Multi-album playlist group headers use the shared 5px corner radius.
- Options uses one Navigation/Options toolbar. Desktop settings use Sound,
  Interface, and Playback tabs; Interface contains the desktop-only Playlist
  column settings. Phones use one four-item
  toolbar for Navigation, Sound, Interface, and Playback; each option page keeps
  its own sections. Fields use equal-width columns and compact descriptions.
  Long Play, Faded Skip, and Native format speed use Yes/No field-style buttons.
- SBO follows the shared SB2 charcoal/cyan palette through theme tokens for
  chrome, raised surfaces, selection, text, and overlays. Player tree rows have
  visible button borders and full touch targets; disclosure chevrons are absent.
  The Back to player action uses a Home icon. Favorites/Recent menu shortcuts
  wait for the player view control to be ready before switching it.
- Sound options provide three EQ preset slots synced to the signed-in account.
  Save copies the current ten-band curve into a slot; Apply restores it and
  enables the EQ. Presets and band gains are available across that account's
  clients.
  EQ, volume, transport fades, and headroom continue to use the single Web Audio
  graph owned by `site-player.js`.
- Native format speed accepts reduced fractions from 1/2 to 2 in 1/64 steps.
  The toolbar toggles this source-decoder tempo, which is applied before AAC
  encoding. Changing it restarts the stream at the same source position. The
  browser audio element plays the encoded stream at its natural rate. The Play
  Speed section contains only this Native format speed setting.
- Interface controls playlist/sidebar font sizes from 10–20px, desktop row gap
  from 0–32px, animation enablement, and its 0–600ms duration. Defaults are 13px,
  0px, and 200ms. SBO desktop sidebar and playlist text use a 1.1 line height to
  keep descenders visible in the compact rows. The shared
  selector, drawer, queue, and navigation use SB2's cubic-bezier(.2,0,0,1) motion;
  reduced-motion device settings take precedence.
- The site Favorites page uses compact desktop rows grouped by member, with
  album artwork, artist, title, added date, and Play. Phones retain track cards.
- Toolbar controls operate the existing hosted engine. Stop retains the selected
  track and queue while resetting playback. Authentication, stream quotas,
  source materialization, favorites, and playback settings retain their contracts.

Both scroll panes fade over 1 rem: clear at the top, 50% background coverage
at the midpoint, and 75% at the bottom. Status text shares READY typography.
Reloading or signing back in restores the current track, queue and position in
the same tab for the same account. Playback resumes automatically when permitted;
otherwise Play resumes the saved position. A full reload briefly recreates the
media connection; ordinary in-site navigation retains the existing player.

Owners choose the global AAC bitrate and playback session limit in Admin →
Audio streaming. AAC bitrate choices are 96, 128, 160, 192 or
256 kbps, with 192 kbps as the default. The session limit is a numeric field
accepting any whole-minute value from 1 through 1,440, defaulting to 120. The
limit starts at the last full page load and is
enforced by both the browser and stream endpoint. The bitrate applies to every
new stream without interrupting existing playback. AAC-LC is the only stream
format; there is no MP3 fallback or MP4 container. An up-to-date browser with
MediaSource or ManagedMediaSource support for `audio/aac` is required. Monthly
usage counts delivered bytes.

Fade Out now applies to every format, including finite Long Play, like SB2.
Zero disables fading. Finite Long Play includes the fade in its selected total;
unlimited timing has no end fade and remains subject to session/quota limits.
Pausing retains buffered audio; interrupted playback resumes at its absolute
position when Play is pressed. Reload/login restores that position with fresh
authorization, subject to browser autoplay policy.

Desktop Favorites and Recent share the two-pane collection layout. The sidebar
lists only albums represented in the current collection, grouped by console;
selecting an album scopes the playlist to its matching titles. Favorites retain
date-added order and show Added; Recent remains newest-played first and shows
Played. The collection shortcut restores the full collection. Mobile has labeled
Library/Gallery/Recent/Favorites views, larger controls, and a persistent bottom
playback dock. The same dock remains accessible on other authenticated pages,
and normal in-site navigation keeps the audio connection alive.

Cleanup audit: retired chat, feed, community, and Spotlight routes redirect. The Spotlight page,
posts, votes, badges, navigation, database tables, and read cursor are removed. Active Listening, profiles, and
member Favorites remain available. Obsolete codec settings and trial plumbing
were removed without deleting unrelated member content.

The phone player uses one compact browsing header and no workspace-tab strip.
Desktop tabs remain saved; mobile hides their management controls rather than
creating another playback state. Stop is desktop-only. Queue uses one title and
one current-track readout. Account portraits remain square. Sidebar levels use
one character of indent, leaves omit disclosure arrows, and expanded mobile
album/track favorites share the same right edge.

Listening and profile/Favorites tracks use one artwork-sized card:
Artwork sits left in a 112-pixel desktop / 96-pixel phone slot; title, metadata,
member/time and actions sit right. Images scale down only, preserving their native
size and aspect ratio. There is no full-width status footer.
Profiles use compact forms and a collapsed bandwidth summary. Select controls
reserve room inside the border for their chevrons.

Shared Listening updates are authenticated using the persistent player's hidden
CSRF token, including on pages with no other forms. Successful presence updates
refresh Listening immediately. Long Play duration is shown in the player's
playlist rows as well as its clock. Normal VGM playback applies the same output
fade envelope as Long Play. Actual Shadow Blasters Boss Theme and Round 8 VGM
fixtures render the requested 180 seconds on the production decoder.


The shared card never overlays text on artwork or enlarges small images. Gallery
cache schema 5 preserves aspect ratio and caps thumbnails at 240px without
upscaling; rebuilding the cache replaces older enlarged thumbnails. On mobile, Previous/Play/Next
live in the existing top toolbar, while the bottom readout occupies 32px plus the
safe area. The browse header is 64px, flat and edge-to-edge, and tree rows have no
rounded panel background. The mobile portrait is 32px square; desktop is 24px.

Options uses one drawer on desktop and mobile. On phones, one Navigation/Options
toolbar sits above a scrollable stack of Sound, Interface, and Playback sections;
Playlist remains desktop-only. Shaded group headers divide Long Play, Fade Out,
Play Speed, and Sound controls. Phone fields and field-style buttons share the
same 50/50 label/control split. Volume and equalizer sliders align, and field
descriptions appear as smaller text below their labels. Safe-area insets remain.


The AAC player automatically reconnects interrupted playback from its current
position, with three bounded attempts. It waits for connectivity while offline;
Pause and Stop cancel recovery. Login, quota and expiry still require the shown
action. Phones with full media buffers can reclaim played audio without changing
codec or quality. Supported browsers expose track metadata and play/pause,
previous/next and seeking through system media controls. Native AirPlay remains
unavailable. Library loading and upfront readiness are unchanged.


Playback prepares compressed source members through VGMBoy's shared engine.
It retains original source bytes and the AAC streaming format; no permanent
extracted library or encoded-song cache is created. A missing preparation runtime
is an explicit error. Playback-source scratch is reclaimed on completion/failure.

### Desktop playlist columns

Year and Dumper can be enabled in Options alongside the existing columns. Empty
metadata columns hide for the current playlist without changing saved choices.
Auto-size fits all displayed rows using the actual font and text casing; Title
keeps its content width. Headers and rows share column positions during resizing
and use the selected interface animation. The hosted catalog currently has no
Year or Dumper values; those columns appear when that metadata is published.

### Desktop Recents

Recent uses the same playlist and column controls as Favorites. Its sidebar shows
albums in the loaded history; selecting one filters the playlist. Clicking Recent
again returns to all loaded events. Repeated plays remain separate entries, newest
first, with a configurable Date/time column. Load older adds the next history page.
Search filters loaded history. Removed tracks remain listed but cannot be played.
Phone history retains its compact cards and swipe-to-hide controls.

### Profile Favorites and Options

Profile → Favorites uses the shared favorite toggle also used by the player. On
touch screens, the row nudges on contact and follows a left
swipe to reveal a large blue accent square with a star; desktop hover/focus also
reveals the action. Removing one song from a favorited album
retains its other songs. The account portrait appears once in the identity
header; the image cropper appears only while selecting a replacement picture.
In-player Favorites stays a simple playlist, matching Recents.

Options uses the charcoal/cyan player theme on desktop and phone: compact shaded
section headings, aligned fields, and matching Volume/equalizer sliders. Phone
fields remain large enough to enter values without browser zoom. The same fonts
and control surfaces extend to profile and listening pages.

### Mobile navigation and Listening

Search shares the top bar with playback. Back to player appears on other pages
and is hidden on SPCBOY. Navigation and Options share the phone drawer, with a
top row switching between them. Navigation contains identity, play count,
online-user count, site links and owner tools. Queue
stays separate. Admin combines global audio settings, accounts and invitations;
the old Profile Site settings URL redirects there.
Listening switches between Now playing and Played, with compact day filters and
track rows on phones.
