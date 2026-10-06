# LineBoy prototype

Standalone visual mockup for a monochrome DOS-style ViewBoy sibling. It uses a
compact CP437-inspired screen font, black and gray surfaces, reverse-video
command blocks, and a simulated monochrome CRT raster. Track and toolbar
controls are local presentation interactions only; this prototype is not wired
to the catalog or playback bridge.

The screen is rasterized from the live interface into a framebuffer, then a
WebGL2 fragment shader draws the image through 480 horizontal beam profiles.
Each profile has a Gaussian phosphor spot whose width increases with brightness,
and the shader emits black outside each spot, leaving actual empty scanline
gaps instead of dimmed copies of the source image. The beam pass runs only after
content, layout, scroll, or pointer state changes. This keeps the mockup
responsive while making each visible row the product of a beam pass. It is a
compact monochrome CRT model, not a complete analog display simulation: it
does not add color phosphor masks, NTSC artifacts, curvature, or beam flicker.
The browser keeps the semantic interface available as a fallback when WebGL2
or framebuffer rendering is unavailable.

`assets/ModernDOS8x16.ttf` is Modern DOS 8x16 by Jayvee Enaguas. It is based on
IBM VGA and Verite PC fonts and is dedicated under CC0 1.0. The font and a copy
of its license are included in `assets/`. Source: [original project](https://notabug.org/HarvettFox96/ttf-moderndos), [read-only mirror](https://github.com/notpeter/ttf-moderndos).

Open `index.html` in a browser, or serve this directory locally with:

```sh
python3 -m http.server 8765 --bind 127.0.0.1 --directory ViewBoy/Prototypes/LineBoy
```
