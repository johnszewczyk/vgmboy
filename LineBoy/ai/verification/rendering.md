# Rendering checks

`node --test LineBoy/Tests/RasterGrid.test.mjs` checks whole-device-pixel glyph
advances and scan-pitch divisibility across the supported profiles and device
ratios. Inline JavaScript passes syntax checking. The native package builds.

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
hardware calibration or live catalog integration. Keep the sample catalog gate
disabled for visual work.
