# LineBoy prototype

Standalone visual mockup for a monochrome DOS-style ViewBoy sibling. It uses a
compact CP437-inspired screen font, black and gray surfaces, reverse-video
command blocks, and a simulated monochrome CRT raster. Track and toolbar
controls are local presentation interactions only; this prototype is not wired
to the catalog or playback bridge.

The UI uses one 8×16 Modern DOS font across toolbar, panels, lists, and status.
The standard mode resolves its font rows to an integer device-pixel cadence:
VGA 640×480 at three device pixels per source pixel when the viewport permits,
then VGA/EGA/QVGA at two pixels per source pixel on smaller screens. Its beam
draws two illuminated pixels followed by one pure-black scanline gap. High
mode keeps a denser two-pixel cadence and selects XGA 1024×768, SVGA 800×600,
VGA 640×480, or EGA 512×384 according to available space. The VIDEO control
switches between these fixed-scale mode families. The interface is rasterized
at the selected source dimensions and centered without fractional stretching.

A WebGL2 fragment shader draws the framebuffer through a beam profile. Its
spot width changes slightly with brightness; pixels outside each spot are
emitted as pure black. Nearest-neighbor texture sampling keeps source pixels
sharp, and text glyph tops snap to the same row cadence as the beam. The pass
runs after content, layout, scroll, or pointer changes. This is a compact
monochrome CRT model, not a complete analog display simulation: it omits color
phosphor masks, NTSC artifacts, curvature, and beam flicker. The browser keeps
the semantic interface available as a fallback when WebGL2 or framebuffer
rendering is unavailable.

`assets/ModernDOS8x16.ttf` is Modern DOS 8x16 by Jayvee Enaguas. It is based on
IBM VGA and Verite PC fonts and is dedicated under CC0 1.0. The font and a copy
of its license are included in `assets/`. Source: [original project](https://notabug.org/HarvettFox96/ttf-moderndos), [read-only mirror](https://github.com/notpeter/ttf-moderndos).

Open `index.html` in a browser, or serve this directory locally with:

```sh
python3 -m http.server 8765 --bind 127.0.0.1 --directory ViewBoy/Prototypes/LineBoy
```
