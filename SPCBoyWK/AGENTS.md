# SPCBoyWK instructions

Read [`ai/AGENTS.md`](ai/AGENTS.md), then
[`ai/project-info.md`](ai/project-info.md), then the focused note routed by the
task.

SPCBoyWK is a retired legacy SPCBOY frontend, superseded by SB2. Retain its
source and package for historical reference and reproducible builds; do not add
features or present it as an active app. Shared catalog, archive, queue,
preference, and playback behavior belongs in CatalogReader, FrontendCore, or
VGMBoy.

`build.sh` remains available for historical source verification. The app is no
longer in LaunchPad. Catalog access stays read-only, and this frontend does not
own scanning, format inspection, decoding, or audio output.
