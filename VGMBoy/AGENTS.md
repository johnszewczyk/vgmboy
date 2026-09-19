# VGMBoy instructions

Read [`ai/AGENTS.md`](ai/AGENTS.md), then
[`ai/project-info.md`](ai/project-info.md), then the narrow subsystem note
routed by the task.

VGMBoy owns playback admission, decoder integration, timing, native transport,
and the macOS audio device. The three maintained player frontends—CocoaSpice,
SPCBoyWK, and ViewBoy—are clients of the shared kit and family service
packages; cross-app behavior belongs with its shared owner. `SPCBoy/` is
recovery-only Electron source; LaunchPad's SPCBoy target is SPCBoyWK.

Do not fork upstream decoders or duplicate a complete MetaMan reader in a
playback/scanner adapter. Keep public APIs narrow, fail explicitly on
unsupported input, and validate the packaged or audible boundary when the task
changes that behavior.
