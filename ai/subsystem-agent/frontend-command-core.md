# Frontend Command Core

## Scope

`FrontendCommandCore` publishes the semantic command names and default shortcut
keys shared by the CocoaSpice and SPCBoy frontend families.

## Ownership

The package defines no AppKit menu, WebKit message handler, Electron
accelerator, or playback implementation. Each host translates the catalog into
its own platform event layer.

## Invariants

- Cmd-Q, Cmd-W, Cmd-M, Cmd-O, Cmd-1/2/3, Cmd-comma, and F7/F8/F9 have one shared semantic definition.
- Host adapters may add skin-specific commands but must not silently rename these common commands.

## Files

- `/Users/john/Downloads/Code/VGMMan/CatalogReader/Sources/FrontendCommandCore/FrontendCommandCore.swift`
- `/Users/john/Downloads/Code/VGMMan/CatalogReader/Tests/FrontendCommandCoreTests/FrontendCommandCoreTests.swift`
