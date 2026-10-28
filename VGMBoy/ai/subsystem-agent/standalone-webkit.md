# Standalone WebKit Host

`Sources/VGMBoyApp` owns the standalone local player presentation. SwiftUI hosts
one WKWebView; its nonpersistent store loads `Resources/index.html` from the
SwiftPM resource bundle. `build-app.sh` copies that bundle into the packaged app.
No remote assets, server or second audio graph are involved.

The coordinator accepts main-frame messages only from the exact bundled page.
Navigation is restricted to that page; CSP excludes network requests and inline
scripts. JavaScript uses textContent for file names/errors and sends commands
through the named player message handler. Native commands validate finite numeric
values and bounds; file access is through NSOpenPanel or native open URLs, never
arbitrary JavaScript paths. State crosses through callAsyncJavaScript arguments.
Local file drops are received by the WKWebView host as an AppKit drag destination
so WebKit cannot swallow them before SwiftUI handles the drop. It accepts Finder
file URLs and the legacy filenames pasteboard type, then routes local URLs through
the native session loader, replacing the current local session. The app registers
the UAC document type for Finder and Dock open events.
Remove the script handler when the web view dismantles; retain no view cycle.

PlayerViewModel owns the in-memory file session and translates controls into the
existing typed PlaybackController API. It never writes the catalog. Decoder
capabilities come from FormatRegistry.playbackDescriptors. Subsong indices are
one-based in the UI and zero-based in the core; shared playback status reports
the decoder's track count so the player can expose a bounded subsong picker for
GBS, NSF, and other multi-track formats. Timing edits preserve position and
paused state. The seek window is a
frontend bound, not authoritative metadata duration. Native output diagnostics
remain read-only. Observation publishes changed snapshots without replacing
focused controls; playback/status events stay on the main actor at the UI edge.

The packaged app is a regular Dock app with a native menu bar. Keep standard
window actions in native command groups so keyboard shortcuts reach AppKit and
focused text controls retain normal editing behavior. The Dock icon is packaged
as an `.icns` resource generated from the source PNG.

Verification must include the packaged app's bundled-resource load, native open
panel, file playback, pause/seek and an Audio/Diagnostics page check. Browser-only
rendering does not prove the native bridge or device output.
