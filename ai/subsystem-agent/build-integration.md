# Build Integration

## Scope

How VGMBoy links the vendored upstream decoder libraries without re-vendoring them.

## Ownership

`Package.swift` links VGMBoy-specific bridge targets and their upstream static libraries. CocoaSpice
links VGMBoyKit and never its former playback bridge targets, so a bundled frontend has exactly one
copy of every bridge module.

## Invariants

- VGMBoy bridge module names are VGMBoy-specific to avoid Swift module-map collisions with a host.
- A frontend links VGMBoyKit as its only audio-core product; duplicate native bridge objects are a linker error.
- Never fork an upstream decoder library per frontend.
- Executable product names must not collide on a case-insensitive filesystem. The CLI is
  `vgmboy-cli`; the GUI app is `VGMBoy`. A `vgmboy` (CLI) vs `VGMBoy` (app) collision silently
  overwrote one binary and must not recur.

## Files

- [Package.swift](/Users/john/Downloads/Code/VGMBoy/Package.swift)
- [build-app.sh](/Users/john/Downloads/Code/VGMBoy/build-app.sh)
