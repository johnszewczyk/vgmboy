# LineBoy prototype

Standalone visual mockup for a monochrome DOS-style ViewBoy sibling. It uses a
compact CP437-inspired screen font, black and gray surfaces, reverse-video
command blocks, outline controls, and horizontal scanlines over the complete
screen area. Track and toolbar controls are local presentation interactions
only; this prototype is not wired to the catalog or playback bridge.

`assets/ModernDOS8x16.ttf` is Modern DOS 8x16 by Jayvee Enaguas. It is based on
IBM VGA and Verite PC fonts and is dedicated under CC0 1.0. The font and a copy
of its license are included in `assets/`. Source: [original project](https://notabug.org/HarvettFox96/ttf-moderndos), [read-only mirror](https://github.com/notpeter/ttf-moderndos).

Open `index.html` in a browser, or serve this directory locally with:

```sh
python3 -m http.server 8765 --bind 127.0.0.1 --directory ViewBoy/Prototypes/LineBoy
```
