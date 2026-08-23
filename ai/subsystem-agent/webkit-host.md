# WebKit Host

## Scope

The native executable owns the application window, a single WKWebView, and
the `spcBoyWK` message bridge.

## Ownership

Swift owns native capabilities and future catalog/playback bridges. The web
resources own presentation and user interaction.

The AppKit host owns Cmd-Q, Cmd-W, Cmd-M, and menu dispatch. Shared semantic
shortcut names and default keys come from `FrontendCommandCore`; WebKit receives
the remaining frontend commands through the narrow `SPCBoyWK` dispatcher.

Archive-backed PSF playback must receive the selected PSF and its `_lib`/`_lib2`
dependency chain in one temporary directory. That resolution belongs to the
shared `ArchiveMaterializationCore`; the WK bridge must not extract a selected
archive member directly.

## Failure Boundaries

Missing packaged resources are fatal. The host must not silently fall back to
raw filesystem scanning or a second catalog implementation.

## Files

- `/Users/john/Downloads/Code/VGMMan/SPCBoyWK/Sources/SPCBoyWK/main.swift`
- `/Users/john/Downloads/Code/VGMMan/SPCBoyWK/Package.swift`
