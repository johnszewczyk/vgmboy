# SBONLINE column motion, Long Play, and GBA capacity

## Implementation

Column auto-sizing measures header/row text rather than distributing widths
across every column. Ordinary metadata columns keep their measured width;
Title absorbs spare space because hosted source paths remain private. One grid
template drives header and rows. Width changes follow the configured interface
duration and cubic-bezier(.2,0,0,1); horizontal scroll keeps the header aligned.
Measurements use at most 1,200 rows and deduplicate strings. The resize observer
watches the viewport rather than triggering itself on animated content widths.

Long Play now accepts seconds, M:SS, or H:MM:SS. Off uses normal format timing,
positive durations provide finite looping, and zero means unlimited musical
timing. New preferences default to 3:00; existing minute preferences migrate.
Finite durations are bounded to 24 hours, and the existing 60-minute page
session deadline and monthly quota still govern every stream. The server turns
zero into a bounded remaining-session decode window without a musical fade.
One absolute output fade spans decoder restarts, avoiding premature loop fades.
Disabled duration edits and unchanged Enter/blur commits do not restart audio.

## Local verification

- Six timing-policy tests passed: finite totals, short fades, unlimited offsets,
  invalid values/positions, 2x session coverage, and long finite durations.
- Both edited JavaScript files passed syntax checks; Django system check and
  Git whitespace checks passed. The hosted C++ decoder built successfully.
- Real VGM and SPC source members rendered exactly 529,200 bytes for 3 seconds
  and 352,800 bytes for a 1-second offset into that 3-second window. Both finite
  fade and no-fade looping cases completed successfully; sources were untouched.
- Desktop header/body x coordinates matched for every column. At 800px width,
  the playlist overflowed by 84px; after actual horizontal scrolling to 84px,
  all six header/body coordinate differences remained zero. Computed transition
  was the configured 0.2s cubic-bezier(.2,0,0,1).
- The duration editor accepted 3:05. Local browser logs were clear of errors.

## GBA disk estimate

Measured source: `/Users/john/Downloads/audio/JoshW/Nintendo Game Boy Advance`.
The existing 7-Zip member tables were listed read-only; nothing was imported,
converted, or extracted into the collection.

| Item | Measured size |
| --- | ---: |
| 1,081 compressed packages | 494,670,440 bytes (494.7 MB / 471.8 MiB) |
| 33,982 unpacked archive members | 574,675,252 bytes (574.7 MB / 548.1 MiB) |
| GSF / miniGSF / GSF library members | 32,181 |
| Largest unpacked package | 7,442,789 bytes (7.44 MB) |
| Server space available before release | 3,040,567,296 bytes (3.04 GB) |

Keeping the packages compressed adds approximately **0.495 GB** of media.
That leaves approximately **2.546 GB** of the measured free space. Reserve
roughly **1 GB** for media plus import/build/cache headroom; this is a planning
allowance, not a measured decoder installation. No pre-encoded AAC library is
needed. Existing backups exclude bulk compressed music packages.

Capacity is sufficient for this specific set. Playback support is separate:
the current web admission list is VGM/VGZ/SPC/NSF/NSFE/GBS, and the streamer uses
libvgm/libgme. GSF decoding and miniGSF dependency materialization still need
integration. Archive access already supports 7z. This report does not claim
GBA playback has been enabled.

## Release boundary

The release preserves the 60-minute wall-clock limit independently of musical
timing and covers unlimited playback at the maximum 2x browser speed. A catalog
request interrupted by a service restart exposed a saved-tab persistence edge:
failed catalog loads now leave stored album selections untouched.

Code checkpoints: `af0bc2c`, `d39b11d`, `83dd4de`.
Rollback tag: `sbonline-before-longplay-parity-20261021`.

Live playback checks after release: finite Long Play sent `longPlay=3`, advanced
through successive catalog tracks at the selected 3-second timing, and showed
matching track/queue clocks. Unlimited sent `longPlay=0`, played beyond 18 seconds
without an audio error, and displayed `0:18 / ∞ / ∞`. Restoring Off removed the
parameter and restored the normal `1:12 / 16:51` duration totals. The player was
left stopped at 0:00, Long Play off, and duration 3:00. Server service was active;
post-release free disk was 3,040,374,784 bytes.

A disposable local 502 catalog-response fixture confirmed that returning to the
normal endpoint restored the saved Chrono Trigger and Search tabs. The final
release completed through the normal deployment command, with the existing
HSTS preload warning only. Final source assets use `20261021-parity-1` and the
failed-load tab guard uses `spcboy.js?v=20261021-parity-2`.
