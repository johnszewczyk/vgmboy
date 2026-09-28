# Options

Options is a full page inside the LCD screen, reached from the Settings tab, key 3, or the macOS Options menu. Library or Queue returns without changing playback.

The initial controls expose Long Play, End Fade, Repeat, Mono, Volume, and Reload Library. Changes persist through the typed `frontendSettingsSave` bridge; audio controls are applied to VGMBoy, and timing controls reconfigure loaded playback. The page also reports the current three-device-pixel dot size and 5×7 bitmap font. It does not yet expose the older interface's equalizer, routing, diagnostics, archive cache, or full typography controls.

The owning files are `Sources/ViewBoy/Resources/yoga-app.js`, `Sources/ViewBoy/WKNativeBridge.swift`, and `Sources/ViewBoy/SPCBoyPreferencesSnapshot.swift`.
