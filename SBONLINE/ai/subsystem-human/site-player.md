# Hosted Site Player

## Player

SBONLINE's authenticated SPCBOY page follows SB2's dark desktop presentation:
a compact title strip, left transport and search toolbars, console/game sidebar,
dense aligned track columns, Gallery, and a narrow status footer. Options uses
a full-width top drawer with a section sidebar and shaded headers. Playlist tabs
remember each account's browsing contexts in the current browser; plus adds a
fresh tab, and album/track context menus can open foreground or background tabs.
Phones retain the top playback bar, saved-tab strip, larger track targets, and
responsive drawers. Desktop and phone site navigation retain the shared player.
Interface options adjust playlist/sidebar font sizes and SB2-style motion timing.
Site Favorites uses dense desktop rows and phone cards.

The toolbar uses the existing hosted player for previous/next, Play/Pause, Stop,
EQ, Long Play, volume, queue, and Options. Stop resets the selected track to the
beginning and retains its queue. The entire site uses the same charcoal/cyan theme;
Profile, Listening, Favorites, Spotlight, and owner tools remain in the account
menu.

Selected tracks stream as 128 kbps AAC. Source packages stay compressed on the
server; only the requested member is materialized for playback. Browser EQ and
fractional playback speed use the existing audio engine. Long Play supports seconds or M:SS/H:MM:SS durations; zero means unlimited,
within the hosted 60-minute session limit. Existing saved durations migrate. Favorites, album favorites, Recent,
Gallery, and the shared player retain their hosted API and account contracts.
The retired Chat and generic Feed do not appear in the player.

The web UI is a hosted adaptation, not the macOS host: native window controls,
local filesystem browsing, catalog maintenance, and native decoder routing are
not browser controls. Production behavior and deployment remain owned by the
[MathBook private-admin notes](../../../../MathBook/ai/subsystem-human/private-admin.md).

## Standalone Concept

[`prototypes/mobile/index.html`](../../prototypes/mobile/index.html) is an older
sample-only visual concept. It is not the hosted player or a playback test.

## Files

- [Hosted player template](../../../../MathBook/private-admin/templates/accounts/spcboy.html)
- [SB2-style hosted skin](../../../../MathBook/private-admin/static/accounts/sbonline.css)
- [Hosted player adapter](../../../../MathBook/private-admin/static/accounts/site-player.js)
- [Hosted library UI](../../../../MathBook/private-admin/static/accounts/spcboy.js)
