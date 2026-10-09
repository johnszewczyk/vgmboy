# AGENTS

This is the current SPCBOY frontend under development in the VGMMan family,
superseding retired SPCBoyWK. SB2 has its own package, app bundle, preference
namespace, and release boundary. Read
`../AGENTS.md`, `../project-info.md`, then `ai/AGENTS.md` and
`ai/project-info.md` before changing implementation.

Keep SPCBOY presentation and host adaptation here. Catalog reads belong to
CatalogReader, shared frontend policy belongs to FrontendCore, and decoding,
timing, and audio output belong to VGMBoy. Do not change SPCBoyWK or CocoaSpice
skins to implement SB2 behavior.
