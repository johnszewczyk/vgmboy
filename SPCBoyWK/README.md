# SPCBoy (WK)

SPCBoyWK is the retired legacy native macOS WebKit SPCBOY frontend in the
VGMMan family. SB2 is its active successor under development. SPCBoyWK source
and package files remain for historical reference and reproducible builds; the
app is no longer listed in LaunchPad and receives no feature work.

The retained frontend owns its historical app identity, AppKit/WKWebView host,
renderer, and typed bridge while sharing catalog, archive, queue, preference,
and playback contracts with the family packages.

Catalog-backed playback uses read-only CatalogReader projections and the shared
FrontendCore archive path. VGMBoyKit owns playback, timing, and audio output.
The local-folder browser handles ordinary loose files; the app does not scan or
write the catalog. Settings open in a separate native window with an independent
WebKit view. The renderer presents authoritative native transport events and
status snapshots.

## Historical build

```sh
./build.sh
```

This builds the retained package for source verification. It is not an active
development frontend. For task routing, read [AGENTS.md](AGENTS.md), then
[`ai/project-info.md`](ai/project-info.md).
