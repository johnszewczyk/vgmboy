# Yoga LCD Canvas Transition

The standalone preview under `/Users/john/.codex/visualizations/2026/09/26/01a0dda1-0db6-7a02-899e-a7956be4204c/viewboy-yoga-lcd/` became ViewBoy's packaged front end in September 2026. Its Yoga layout and four-shade canvas were copied into ViewBoy resources, and the sample library/playback state was replaced with calls through the existing native bridge. The old packaged WebKit renderer was saved in `LocalRecovery/ViewBoy/ViewBoy-webkit-9a2048ed.zip` and removed from active resources.

The framebuffer uses a 5×7 bitmap font and a 3×3 device-pixel cell with a 2×2 shaded face. This is an initial display setting, not a finalized limit on software pixel size. The current front end provides a system/game tree, a compact track list, native transport controls, local path intake, and full-screen Options. Playlist tabs, Favorites, equalizer, and other old controls remain to be ported.
