# SPCBOY SB2

SPCBOY SB2 is the current SPCBOY WebKit frontend under development in the
VGMMan family, superseding retired SPCBoyWK. It has its own app identity,
preference namespace, archive cache, and compact pixel-style presentation.
Catalog access, queue policy, and playback remain behind the shared
CatalogReader, FrontendCore, and VGMBoy package boundaries.

The main window contains the approved dense home layout. Options open as a
subpage and keep SPCBOY-owned interface/database settings separate from
VGMBoy-owned playback settings.

## Build and run

```sh
./launch.sh
```

`launch.sh` rebuilds and opens a fresh app instance. Use `./build.sh` by itself
to package without launching.

## Requirements

- macOS 26 or later. The Swift package's deployment target is macOS 26.
- Xcode and its command-line tools, with SwiftPM support for the Swift 6.3
  package manifest, plus CMake and a C/C++ compiler for VGMBoy's vendored
  decoder dependencies. The build script prepares those dependencies; no
  separate decoder installation is needed.
- The VGMMan sibling packages must be present at `../CatalogReader`,
  `../FrontendCore`, and `../VGMBoy`.
- To populate the library, SB2 reads the shared ScanSong catalog read-only.
  It defaults to `~/Library/Application Support/CocoaSpice/Library.sqlite`;
  set `SPCBOY_SB2_CATALOG_PATH` to use another catalog.

The build uses the configured SPCBOY signing identity when available and falls
back to ad-hoc signing otherwise.

Set `SB2_BUILD_DIR` and `SB2_APP_DIR` to place build products outside this
directory. See [AGENTS.md](AGENTS.md) and [`ai/project-info.md`](ai/project-info.md)
for the component route.
