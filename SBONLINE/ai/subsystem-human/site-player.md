# Hosted Site Player

## Player

SBONLINE is the authenticated hosted SPCBOY player. Desktop keeps the
wide-library layout with console/game browsing, aligned playlist columns,
gallery, site navigation, and the persistent player. Mobile uses a compact app
bar with Playing, Library, Gallery, Sound, and Options pages. Playing shows the
current track and its album track list; Library and Gallery keep their existing
catalog and album browsing behavior.

Sound groups volume, the ten-band equalizer and presets, long play, fade-out and
faded skips, and native-format playback speed. Options contains site interface
preferences such as playlist and sidebar font size, row gap, and motion. Sound
and Options use the same account-backed controls as the rest of the app, so
their saved values follow the signed-in user across clients. Range sliders have
large phone touch targets; mobile EQ and Volume values stack below their labels
to leave more horizontal room for each slider. The mobile Equalizer toggle is a
full-width “Equalizer ON/OFF” button and uses the existing SB2/SBO accent token.
Numeric controls have clear labels and no trailing unit text.

The persistent player keeps audio active while users change site pages. On
mobile, the app pages provide the primary transport and the bottom status dock
remains visible. The navigation drawer remains available for account, site,
and administrative links.

## Audio and account behavior

Selected tracks stream as 128 kbps AAC. Source packages stay compressed on the
server; only the requested member is materialized for playback. Browser EQ and
fractional playback speed use the hosted audio engine. A saved non-1× rate
remains enabled when upgrading; new 1× settings start disabled. Long Play
supports seconds or M:SS/H:MM:SS durations; zero means unlimited within the
hosted session limit. Favorites, Recent, Gallery, and playback history use the
authenticated account APIs.

The web UI is a hosted browser application, not the SB2 macOS host: native
window controls, local filesystem browsing, catalog maintenance, and native
decoder routing are not browser controls.

## Prototype

[`prototypes/mobile/index.html`](../../prototypes/mobile/index.html) remains a
sample-data design fixture. It is not connected to the hosted catalog, account,
or audio stream and is not playback evidence.

## Production source

- [Player template](../../server/templates/accounts/spcboy.html)
- [Base account template and shared settings](../../server/templates/accounts/base.html)
- [Hosted theme](../../server/static/accounts/sb-theme.css)
- [Hosted mobile layout](../../server/static/accounts/sb-mobile.css)
- [Player page adapter](../../server/static/accounts/spcboy.js)
- [Audio engine](../../server/static/accounts/site-player.js)
- [Account and site administration](site-admin.md)
