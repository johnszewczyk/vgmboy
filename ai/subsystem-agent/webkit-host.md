# WebKit Host

## Scope

The native executable owns the application window, a single WKWebView, and
the `spcBoyWK` message bridge.

## Ownership

Swift owns native capabilities, catalog/playback bridges, persistent settings,
sidebar resolution, and favorite mutation. The web resources own DOM
presentation, CSS animation, and user-interaction forwarding.

Frontend settings cross the bridge as a JSON projection of the typed Swift
`SPCBoyPreferencesSnapshot` and are retained by native `UserDefaults`. Browser
`localStorage` and the retired favorites migration payload are not part of the
runtime persistence path.

The shared `FrontendPreferencesCore` contract owns the validated animation
timing range and 200 ms defaults. DOM geometry and CSS remain WebKit-owned so
SPCBoy keeps its rendering style; native Swift owns persistence and window
levels.

`FrontendOptionsManifest` provides the common Database, Interface, and Windows
organization through the bridge. `options-controller.js` applies that manifest,
`playlist-controller.js` reduces selection, and `sidebar-controller.js` forwards
row gestures to the native shared reducer. `app-ui.js` remains the renderer and
event wiring layer rather than the owner of those policies.

The AppKit host owns Cmd-Q, Cmd-W, Cmd-M, Cmd-O, native file/folder selection, and menu dispatch. Shared semantic
shortcut names and default keys come from `FrontendCommandCore`; WebKit receives
the remaining frontend commands through the narrow `SPCBoyWK` dispatcher.

Archive-backed PSF playback must receive the selected PSF and its `_lib`/`_lib2`
dependency chain in one temporary directory. That resolution belongs to the
shared `ArchiveMaterializationCore`; the WK bridge must not extract a selected
archive member directly.

Playback timing requests are normalized by the shared `VGMBoyKit.PlaybackTimingRequest` at the
native bridge. JavaScript forwards Long Play and deliberate faded-skip intent; it does not choose
the core's standard/timed duration policy. Ordinary finite audio therefore reaches VGMBoy with
decoder-natural timing, while Long Play is the only normal path that supplies a manual length.
For a row without catalog timing, the renderer currently uses its persisted manual duration for
the provisional readout, while the native standard request leaves the play length unset and
VGMBoyKit applies its fixed 150-second unknown-duration safety window. Native status is the
playback authority; the two values must not be treated as equivalent.

## Failure Boundaries

Missing packaged resources are fatal. The host must not silently fall back to
raw filesystem scanning or a second catalog implementation.

## Files

- `/Users/john/Downloads/Code/VGMMan/SPCBoyWK/Sources/SPCBoyWK/main.swift`
- `/Users/john/Downloads/Code/VGMMan/SPCBoyWK/Package.swift`
- `/Users/john/Downloads/Code/VGMMan/SPCBoyWK/Sources/SPCBoyWK/Resources/options-controller.js`
- `/Users/john/Downloads/Code/VGMMan/SPCBoyWK/Sources/SPCBoyWK/Resources/playlist-controller.js`
- `/Users/john/Downloads/Code/VGMMan/SPCBoyWK/Sources/SPCBoyWK/Resources/sidebar-controller.js`
