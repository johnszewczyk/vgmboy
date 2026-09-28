# Yoga LCD Canvas Preview

## Status and scope

This document records the isolated Yoga canvas preview used to explore a
screen-first ViewBoy interface. It describes a design exploration, not the
packaged ViewBoy application. The maintained app and its WebKit, CSS, and Metal
ownership remain as documented in subsystem-human/display.md and
subsystem-agent/viewboy-integration.md.

The preview source currently lives outside the VGMMan repository. Its current
host-local path is
/Users/john/.codex/visualizations/2026/09/26/01a0dda1-0db6-7a02-899e-a7956be4204c/viewboy-yoga-lcd/.
It is served locally at http://127.0.0.1:8766/. Neither the preview source nor
its yoga-layout dependency is included in the ViewBoy app package or this
repository.

## Display model

The preview uses Yoga to arrange an interface, then paints every control, row,
border, selection, and character into a four-shade framebuffer. Text uses a
local 5×7 bitmap glyph table with a six-dot advance. Browser text and native
fonts are not layered over the display.

The responsive grid is independent of the Game Boy's 160×144 resolution. Each
logical LCD dot is expanded to a 3×3 device-pixel cell with a 2×2 shaded face;
the remaining seam uses the unlit screen background. Every framebuffer shade
maps to one palette entry, with no blended edge colors. The current palette
is #0C300C, #285428, #78940D, and #9BBC0F.

## Screen layout and controls

The first toolbar row contains Library, Queue, and Settings. A second row
contains outlined Previous, Play/Pause, Next, and Stop controls. Library shows
a collection sidebar beside a catalog. Queue uses the full pane for a table
with track title, collection, system, and time columns; less important columns
collapse at narrower widths. The bottom strip shows the current selection and
playback state. Settings currently presents display choices. The ten-band
equalizer is absent from this exploration.

The sample playlist metadata is representative layout content, not a live
catalog projection. Clicking page tabs, rows, and transport controls updates
the framebuffer. Keys 1–3 switch pages, the arrow keys move track selection,
and Space toggles playback.

## Evidence and limits

The local preview was checked in the browser at http://127.0.0.1:8766/.
Library, Queue, and Settings navigation, Play/Pause, and arrow-key selection
were exercised. node --check app.js passed, and all 56 glyphs were checked
for seven rows of five bits. This is browser evidence for the standalone
preview only; it is not a packaged ViewBoy build or a live catalog/playback
test.
