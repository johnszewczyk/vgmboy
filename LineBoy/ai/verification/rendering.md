# Rendering checks

`node --test LineBoy/Tests/RasterGrid.test.mjs` checks whole-device-pixel glyph
advances, whole source-pixel scale and scan-pitch divisibility across the supported
profiles and device ratios. The former 2.25× scale now resolves to 2×; the 4×
scale used by the accurate 512 profile remains 4×. Inline JavaScript passes syntax checking. The native package builds.

The native sample screen was visible at 640×480 and switched to 800×600; tabs,
DOM text and the stationary scanline mask remained present. Raising the native
window resolved an initially blank inactive-window capture. No host frame change
was required. Real-file playback remains unverified.

The high-resolution DOS layout pass was built and checked in the native app at
800×600 profile / 118×44 visible cells. The eight framed toolbar actions,
aligned library search and tab band, shaded track headings and full sample game
names were visible. A saved 14-column sidebar correctly clamped to the new
20-column high-resolution minimum. Clicking its divider then pressing Right/Left
changed 20→21→20 columns. Creating a third tab and closing its own pixel-X target
restored the original two tabs. The final removal of the tab maximum width lets
two tabs fill the strip; the same grow/scroll path is retained. Overflow wheel
gestures and drag cancellation were not re-exercised in this pass.

These checks establish grid arithmetic and a visible sample screen, not CRT
hardware calibration. The browser preview remains sample-only. The native app
was also checked against the live catalog: it loaded 49.9K games and 454.9K
tracks, expanded a cached system group, and populated a real 20-track playlist
with shared metadata columns. Starting its selected VGM updated VGMBoy
transport status to PLAYING; it was then paused. Audible output was not
independently monitored.

The scanline correction was rebuilt and inspected in the native WKWebView at
512, 800 and 1024 profiles. The current window reported 4PX pitch at 512 and
2PX at 800/1024; the higher-profile text and shaded surfaces showed consistent
line spacing. The 1024 profile was restored after inspection. The layer is now
outside terminal zoom and the screen origin is snapped to physical pixels.
Fractional-DPR physical displays and the CSS fallback were not visually tested.

On 2026-10-15, `./LineBoy/launch.sh` rebuilt and launched the updated native app.
The saved 20-track 1943 playlist appeared while the catalog sidebar still showed
CONNECTING CATALOG; after bootstrap the library showed 49.9K games and 454.9K
tracks. Selecting Air Buster displayed READING PLAYLIST INDEX… immediately and
then populated 20 tracks. Returning to the saved 1943 game restored its 20 rows
from the recent-playlist cache. The prior 1943 playlist was restored as active
after this interaction check. Automated tests were not run.

On 2026-10-16, `./LineBoy/build.sh` completed and the native app was inspected at
the 320, 512, 640, 800 and 1024 raster profiles. Playlist rows and the sticky
heading remained on the 16px source grid at each profile. The playlist scrolled
vertically as one surface while its heading stayed pinned; the equal-width tab
strip and compact centered close icons were visible. The default sidebar and
Home target now use one quarter of the available columns; the saved width value
was preserved. OPTIONS showed grouped raised cards and the revised EQ band
sliders with their labels and readouts fitting at 640. The saved 640 profile and
top-of-playlist position were restored after inspection. Horizontal playlist
scrolling is implemented by the shared scroll container but was not independently
verified by this native interaction pass. Automated tests were not run.

On 2026-10-16, `./LineBoy/launch.sh` rebuilt and launched the toolbar/footer
layout. The 320, 512, 640, 800 and 1024 profiles showed the unlabeled resolution
blocks on the first row, matching command blocks on the next row, and the name,
grid, beam pitch, clock, current item and playback state in the two-line footer.
The selected raster and toolbar text remained centered on 16px lines. OPTIONS
was visually checked at each profile; category buttons, section headings and
setting buttons use square color blocks, while range controls use square
selector handles. The original 640 profile and LIST view were restored.
Automated tests were not run.
