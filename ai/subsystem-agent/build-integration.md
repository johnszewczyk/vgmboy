# Build Integration

## Scope

How VGMBoy links the vendored upstream decoder libraries without re-vendoring them.

## Ownership

`Package.swift` derives the CocoaSpice root from the package file path and links each upstream
static library from CocoaSpice's `.build` plus the matching vendored include directories. Bridge
glue lives in VGMBoy (`Sources/C<Core>`); the static libraries are built by CocoaSpice's
`scripts/build-*.sh` and consumed here.

## Invariants

- `build-app.sh` checks each required static library and runs the corresponding CocoaSpice build
  script only when it is missing, so a clean check-out self-heals from CocoaSpice's vendor copy.
- Never fork or rebuild upstream libraries inside VGMBoy.
- Executable product names must not collide on a case-insensitive filesystem. The CLI is
  `vgmboy-cli`; the GUI app is `VGMBoy`. A `vgmboy` (CLI) vs `VGMBoy` (app) collision silently
  overwrote one binary and must not recur.

## Files

- [Package.swift](/Users/john/Downloads/Code/VGMBoy/Package.swift)
- [build-app.sh](/Users/john/Downloads/Code/VGMBoy/build-app.sh)
