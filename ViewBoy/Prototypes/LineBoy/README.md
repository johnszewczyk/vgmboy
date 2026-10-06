# LineBoy prototype

Standalone visual mockup for a monochrome DOS-style ViewBoy sibling. It uses a
compact CP437-inspired screen font, black and gray surfaces, reverse-video
command blocks, and a simulated monochrome CRT raster. Track and toolbar
controls are local presentation interactions only; this prototype is not wired
to the catalog or playback bridge.

The screen uses fixed 4:3 raster modes, selecting the largest mode that fits
the viewport: XGA 1024×768, SVGA 800×600, or VGA 640×480. The interface is
rasterized at the selected mode's dimensions and centered without stretching.
A WebGL2 fragment shader draws the framebuffer through a beam profile on a
fixed two-logical-pixel cadence, snapped to whole device pixels. The beam
profile has a Gaussian spot whose width increases slightly with brightness;
pixels outside each spot are emitted as pure black, leaving consistent empty
scanline gaps. The framebuffer texture uses nearest-neighbor sampling so its
source pixels do not blur together. The beam pass runs only after content,
layout, scroll, or pointer state changes. This is a compact monochrome CRT
model, not a complete analog display simulation: it does not add color
phosphor masks, NTSC artifacts, curvature, or beam flicker. The browser keeps
the semantic interface available as a fallback when WebGL2 or framebuffer
rendering is unavailable.

`assets/ModernDOS8x16.ttf` is Modern DOS 8x16 by Jayvee Enaguas. It is based on
IBM VGA and Verite PC fonts and is dedicated under CC0 1.0. The font and a copy
of its license are included in `assets/`. Source: [original project](https://notabug.org/HarvettFox96/ttf-moderndos), [read-only mirror](https://github.com/notpeter/ttf-moderndos).

Open `index.html` in a browser, or serve this directory locally with:

```sh
python3 -m http.server 8765 --bind 127.0.0.1 --directory ViewBoy/Prototypes/LineBoy
```
