# State and WebKit verification — 2026-10-20

## Build and source

The SB2 release product compiles, links and packages successfully against the
existing decoder archives. The signed app passes `codesign --verify --deep
--strict`. Changed JavaScript passes `node --check`; packaged resources match
source. No test suites were added or run, following the component's agent rule.

The normal dependency rebuild first encountered stale libvgm SDK include paths.
Refreshing its generated include configuration allowed that dependency to build.
The remaining full dependency rebuild fails in Play's vendored zlib under SDK
27 (`adler32_combine64` conflicting types). No decoder source was changed. SB2
was built and packaged with the normal script's dependency-build step omitted,
retaining existing decoder archives. This is not proof of a clean decoder build
or an audio regression sweep.

## Native checks

The packaged WKWebView loaded bundled scripts, styles, SVG icons and the actual
catalog under the CSP/navigation policy. It restored the two original playlists
and reported 49,861 games across 306 systems.

Command-T followed immediately by Command-Q completed in one UI batch. The
persisted workspace contained three tabs, and relaunch restored the temporary
third tab as active. Closing that tab and using the custom window close control
saved the original two-tab workspace and terminated without a save error.

Audio options remained usable; a volume change updated the displayed value and
was restored to its original 100%. No playback was started. The final package
includes the canonical preference-patch path and normalized-value observation.

## Limits

Two-window competing preference edits, save-failure/timeout UI, foreign-document
navigation rejection and large-playlist scroll performance were reviewed in
source but not exercised with native fault injection or performance measurement.
The full model render still validates membership; the scroll callback now calls
the viewport reconciler directly and selection membership is cached separately.
