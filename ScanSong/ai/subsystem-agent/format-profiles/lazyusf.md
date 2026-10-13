# Format profile: `lazyusf`

Parent playback plugin: `lazyusf`. This page groups the subformats admitted by that plugin and records their ScanSong route, metadata source, and format-specific boundaries. The shared registry matrix, route inventory, and scanner contracts remain in [format-accommodations.md](../format-accommodations.md).

## `.usf` and `.miniusf`

The `lazyusf` ScanSong route publishes one structurally-known row per source
using the shared [PSF-style footer reader](playpsf.md#shared-psf-style-footer-reader).
It does not validate compressed payloads or resolve playback libraries.
`.usflib` is dependency data, never a track; see the [shared PSF sidecar
rule](playpsf.md#shared-psf-sidecars).
