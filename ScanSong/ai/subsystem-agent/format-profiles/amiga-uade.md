# Format profile: `amiga-uade`

Parent playback plugin: `amiga-uade`. This page groups the subformats admitted by that plugin and records their ScanSong route, metadata source, and format-specific boundaries. The shared registry matrix, route inventory, and scanner contracts remain in [format-accommodations.md](../format-accommodations.md).

## Amiga replayer-prefix subformats

Amiga music is a special route because many historical files identify the
EaglePlayer from a leading filename token rather than a conventional suffix.
ScanSong admits known UADE prefixes such as `mod.*`, `p4x.*`, `med.*`,
`mdat.*`, `smpl.*`, TFMX, and custom-player names through the shared
`AmigaFormatManifest`; an ordinary `music.mod` remains an OpenMPT module.
Loose files and members inside `.lha` archives use the same path-aware route.

The scanner extracts `.lha` with the existing bounded 7zz archive boundary,
then materializes the complete extracted Amiga set before invoking the
VGMBoy-built `vgmboy-amiga-inspect` adapter. This is required because an
Amiga set may contain a module, player companion, or sample bank in the same
archive. Companion data is available to UADE but is not published as a second
track source. UADE reports the actual subsong range, so ScanSong publishes one
row per declared subsong with the same zero-based contiguous track indexes used
by VGMBoy playback. The original module and companion bytes are preserved;
ScanSong does not convert them to WAV or flatten them into a new container.

The current shareable runtime is Homebrew UADE 3.05. UADE is GPL-2.0-only (not
GPL-2.0-or-later), so distribution must keep its license obligations and the
runtime data directory in view. A valid UADE open establishes format support;
native duration may remain zero for EaglePlayers that do not expose a finite
length, in which case VGMBoy's normal natural-end or bounded playback policy
applies. Decode/open failures remain visible `archive-error` records and are
never replaced with a fabricated one-track success.
