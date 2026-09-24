# ViewBoy

ViewBoy is the VGMMan family's phosphor-styled native WebKit player. It is a
separate frontend from SPCBoyWK, with its own app identity, visual resources,
and preferences. Both frontends use the shared catalog and playback packages.

ViewBoy reads the schema-24 catalog through CatalogReader and sends playback
requests through FrontendCore to VGMBoy. It does not scan or write catalogs,
decode audio, or own archive extraction policy.

From this directory, run `./launch.sh` to clean-build, package, and open
`.build/ViewBoy.app`. `node --test Tests/ViewBoyTransport.test.js` runs the
renderer and bridge contract tests.

For engineering routes, read [`AGENTS.md`](AGENTS.md), then
[`ai/project-info.md`](ai/project-info.md). The phosphor presentation is
described in [`ai/subsystem-human/display.md`](ai/subsystem-human/display.md).
Current UI parity and open checks are in
[`ai/reports/frontend-parity.md`](../ai/reports/frontend-parity.md).
