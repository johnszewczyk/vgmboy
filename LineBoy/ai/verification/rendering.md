# Rendering checks

`node --test LineBoy/Tests/RasterGrid.test.mjs` checks whole-device-pixel glyph
advances and scan-pitch divisibility across the supported profiles and device
ratios. Inline JavaScript passes syntax checking. The native package builds.

The native sample screen was visible at 640×480 and switched to 800×600; tabs,
DOM text and the stationary scanline mask remained present. Raising the native
window resolved an initially blank inactive-window capture. No host frame change
was required. Overflow tab gestures and real-file playback remain unverified.

These checks establish grid arithmetic and a visible sample screen, not CRT
hardware calibration or live catalog integration. Keep the sample catalog gate
disabled for visual work.
