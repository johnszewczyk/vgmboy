# WebKit Host

## Scope

The native executable owns the application window and a single WKWebView.

## Ownership

Swift owns native capabilities and future catalog/playback bridges. The web
resources own presentation and user interaction.

## Failure Boundaries

Missing packaged resources are fatal. The host must not silently fall back to
Electron, raw filesystem scanning, or a second catalog implementation.

## Files

- `/Users/john/Downloads/Code/SPCBoy (WK)/Sources/SPCBoyWK/main.swift`
- `/Users/john/Downloads/Code/SPCBoy (WK)/Package.swift`
