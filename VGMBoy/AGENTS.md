# AGENTS

Read `ai/AGENTS.md`, then `ai/project-info.md`, then the narrow subsystem note routed by the task.

## Engineering

- VGMBoy owns the macOS audio device and transport. Front-ends (parent apps) are thin clients.
- Piece out the best bridge cores from SPCBoy and CocoaSpice; never fork the shared upstream
  decoder libraries (libgme, libvgm, vgmstream, ...) per app.
- Use boring, simple vanilla features. Fail hard and loud: unsupported input is an explicit error,
  never an invented track.
- Keep the kit's public API surface small and deliberate; the CLI and the SwiftUI app are two thin
  skins over the same core.
- Leave parent apps (SPCBoy, CocoaSpice, ScanSong) untouched until VGMBoy reaches a ready
  state; wire them in later.