# SPCBoyWK instructions

Read [`ai/AGENTS.md`](ai/AGENTS.md), then
[`ai/project-info.md`](ai/project-info.md), then the focused note routed by the
task.

SPCBoyWK is a maintained, independent WebKit player in the VGMMan family. Keep
its bundle identity, preference namespace, WebKit presentation, and narrow
native bridge separate from ViewBoy. Shared catalog, archive, queue, preference,
and playback behavior belongs in CatalogReader, FrontendCore, or VGMBoy.

`launch.sh` performs a clean release build before launch. Catalog access stays
read-only, and this frontend does not own scanning, format inspection, decoding,
or audio output.
