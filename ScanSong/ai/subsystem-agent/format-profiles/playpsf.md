# Format profile: `playpsf`

Parent playback plugin: `playpsf`. This page groups the subformats admitted by that plugin and records their ScanSong route, metadata source, and format-specific boundaries. The shared registry matrix, route inventory, and scanner contracts remain in [format-accommodations.md](../format-accommodations.md).

## Shared PSF-style footer reader

The scanner routes for PSF/PSF2, SSF, USF, and 2SF use MetaManCore's bounded
PSF-style `[TAG]` reader. It preserves ordered fields, duplicates, unknown
keys, and original footer bytes, then projects common identity fields and
authored `length`/`fade` without emulation. Tag parsing is bounded to 1 MiB,
while the raw footer remains available. When a footer is absent, the title
falls back to the filename and the extension supplies the system name. The
reader does not validate compressed program payloads or resolve playback
libraries; those remain playback concerns.

Against the read-only live root-1 catalog, all 14,994 rows across 308 source
containers matched the saved catalog's metadata, timing, and track structure
exactly. Optimized Release inspection measured 0.071 ms median and 0.090 ms p95
per member; this is a local-corpus result, not a cross-machine guarantee.

## `.psf` and `.psf2`

`play-psf1` and `play-psf2` each publish one structurally-known row per source
using the shared footer reader above. `.psflib` files are playback dependency
data, never independent scanner rows. The shared sidecar behavior is summarized below.

## Shared PSF sidecars

The recognized support names are `.psflib`, `.2sflib`, `.gsflib`, `.qsflib`,
`.ssflib`, and `.usflib`. They are omitted from archive `unrecognized`
diagnostics and standalone `.zst` discovery. Playback must still materialize
the complete dependency set for cores that require it. GSF and QSF container,
payload, and library validation are covered by their [GSF](highly-complete.md)
and [QSF](qsf.md) profiles; generic footer readability alone does not prove
playback.
