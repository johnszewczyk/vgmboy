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
./build.sh
./launch.sh
```

Set `SB2_BUILD_DIR` and `SB2_APP_DIR` to place build products outside this
directory. See [AGENTS.md](AGENTS.md) and [`ai/project-info.md`](ai/project-info.md)
for the component route.
