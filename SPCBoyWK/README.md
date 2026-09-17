# SPCBoy (WK)

SPCBoyWK is a maintained native macOS WebKit player frontend in the VGMMan
family. It owns its app identity, AppKit/WKWebView host, renderer, and typed
bridge while sharing catalog, archive, queue, preference, and playback
contracts with the other family packages.

Catalog-backed playback uses read-only CatalogReader projections and the shared
FrontendCore archive path. VGMBoyKit owns playback, timing, and audio output.
The local-folder browser handles ordinary loose files; the app does not scan or
write the catalog. Settings open in a separate native window with an independent
WebKit view. The renderer presents authoritative native transport events and
status snapshots.

## Build and run

```sh
./build.sh
./launch.sh
```

`launch.sh` performs a clean release build and opens the packaged app. For task
routing, read [AGENTS.md](AGENTS.md), then [`ai/project-info.md`](ai/project-info.md).
The focused user behavior and engineering constraints are linked there.
