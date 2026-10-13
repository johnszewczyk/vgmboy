# ScanSong route profile: `highly-theoretical`

This is the ScanSong route id for `.ssf` and `.minissf`, not an active playback
plugin. It uses the shared [PSF-style footer reader](playpsf.md#shared-psf-style-footer-reader)
for one structurally-known row per source. VGMBoy's active playback registry
does not admit SSF, so this route remains a scanner-only format and a playback
coverage gap.

## `.ssf` and `.minissf`

`highly-theoretical` reads authored `[TAG]` metadata, including ordered and
duplicate fields, but does not validate the compressed payload or resolve
`.ssflib` dependencies. The sidecar remains support data rather than a track;
see the [shared PSF sidecar rule](playpsf.md#shared-psf-sidecars).
