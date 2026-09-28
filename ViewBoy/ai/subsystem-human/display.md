# Display

The current screen is one canvas laid out with bundled Yoga 3.2.1 WebAssembly. Library shows a system and game tree beside a compact track table. Queue shows the table across the screen. Settings replaces the content with an Options page. The top two rows are page tabs and rectangular transport buttons; the bottom strip shows the current track and transport state. This is a minimalist terminal-like layout with shaded selection bars.

Every control, border, row, and character is painted into a four-shade framebuffer. Text uses a 5×7 bitmap glyph with a six-dot advance. Unsupported characters currently render as `?`; the font is deliberately small and needs broader coverage. Rows are paged to the visible count and scroll with the mouse wheel. Arrow keys change the selected track, Enter plays it, Space toggles transport, and 1–3 change pages. Double-click plays a row.

The LCD currently uses three physical display pixels per software dot. A 2×2 face and a one-pixel seam produce the dot effect. The canvas is crisp-scaled using `devicePixelRatio`; the exact size and subpixel treatment remain an open display decision. The palette is `#0C300C`, `#285428`, `#78940D`, and `#9BBC0F`.

The older Metal phosphor overlay implementation remains in source but is not mounted by the current host. It was designed for DOM geometry and would require a new canvas-aware geometry contract. The active screen is the Yoga canvas in `Sources/ViewBoy/Resources/yoga-app.js`, `yoga-screen.css`, and `index.html`.
