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
